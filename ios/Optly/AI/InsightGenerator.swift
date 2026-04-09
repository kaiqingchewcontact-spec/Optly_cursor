//
//  InsightGenerator.swift
//  Optly
//
//  Orchestrates on-device and cloud AI to produce prioritized ``InsightCard`` models.
//

import Foundation
import Combine

// MARK: - Insight models

/// A single user-facing insight tile with impact scoring and optional A/B variant tagging.
public struct InsightCard: Identifiable, Sendable, Equatable {
    public enum Source: String, Sendable {
        case onDevice
        case cloud
        case hybrid
    }

    public enum Category: String, Sendable {
        case health
        case finance
        case calendar
        case habits
        case crossDomain
    }

    public var id: String
    public var title: String
    public var body: String
    public var category: Category
    public var impactScore: Double
    public var source: Source
    public var experimentVariant: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        category: Category,
        impactScore: Double,
        source: Source,
        experimentVariant: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.impactScore = impactScore
        self.source = source
        self.experimentVariant = experimentVariant
        self.createdAt = createdAt
    }
}

// MARK: - Habit snapshot (inject from app state)

public struct HabitInsightSnapshot: Sendable {
    public var streakDays: Int
    public var completionRate7d: Double
    public var preferredSlotFree: Bool

    public init(streakDays: Int, completionRate7d: Double, preferredSlotFree: Bool) {
        self.streakDays = streakDays
        self.completionRate7d = completionRate7d
        self.preferredSlotFree = preferredSlotFree
    }
}

// MARK: - Generator

/// Combines ``HealthKitService``, ``FinanceService``, ``CalendarService``, habits, ``OnDeviceAIEngine``, and ``CloudAIService``.
public final class InsightGenerator: @unchecked Sendable {

    public let health: HealthKitService
    public let finance: FinanceService
    public let calendar: CalendarService
    public let onDevice: OnDeviceAIEngine
    public let cloud: CloudAIService

    private let calendarClock: Calendar
    private let insightsSubject = CurrentValueSubject<[InsightCard], Never>([])
    private var refreshTask: Task<Void, Never>?

    /// Ordered insights (highest impact first).
    public var insightsPublisher: AnyPublisher<[InsightCard], Never> {
        insightsSubject.eraseToAnyPublisher()
    }

    /// Persisted map of insight IDs users acted on (e.g. tapped primary CTA).
    private let actedKey = "com.optly.insights.actedIds"
    private let defaults: UserDefaults

    public init(
        health: HealthKitService,
        finance: FinanceService,
        calendar: CalendarService,
        onDevice: OnDeviceAIEngine,
        cloud: CloudAIService,
        calendarClock: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        self.health = health
        self.finance = finance
        self.calendar = calendar
        self.onDevice = onDevice
        self.cloud = cloud
        self.calendarClock = calendarClock
        self.defaults = defaults
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: Generation

    /// Builds on-device insights immediately and optionally enriches with a cloud briefing.
    public func generateInsights(
        habit: HabitInsightSnapshot,
        includeCloudBriefing: Bool,
        experimentVariant: String? = nil
    ) async throws -> [InsightCard] {
        let today = Date()
        let healthSummary = try await health.fetchTodaySummary()
        let meetingDensity = try calendar.meetingDensity(events: try calendar.fetchEvents(forDayContaining: today), on: today)
        let hour = calendarClock.component(.hour, from: today)
        let weekend = calendarClock.isDateInWeekend(today)

        let energyInput = EnergyPredictionInput(
            sleepHours: healthSummary.sleepHours,
            stepCount: healthSummary.stepCount,
            activeEnergy: healthSummary.activeEnergyKilocalories,
            meetingDensity: meetingDensity,
            hourOfDay: hour
        )
        let energy = await onDevice.predictEnergyLevel(input: energyInput)

        let habitInput = HabitSuccessInput(
            streakDays: habit.streakDays,
            completionRate7d: habit.completionRate7d,
            preferredSlotFree: habit.preferredSlotFree,
            weekend: weekend
        )
        let habitP = onDevice.habitSuccessProbability(input: habitInput)

        let monthSpend = try await finance.monthlySpendByCategory(forMonthContaining: today)
        let topCategory = monthSpend.max(by: { $0.value < $1.value })
        let recurring = finance.detectRecurringCharges(in: try await finance.fetchTransactions(
            start: calendarClock.date(byAdding: .month, value: -3, to: today) ?? today,
            end: today
        ))
        let subs = finance.detectSubscriptions(recurring: recurring)
        let unused = finance.unusedSubscriptions(subs)

        var cards: [InsightCard] = []

        cards.append(InsightCard(
            title: "Energy outlook",
            body: String(format: "Estimated energy today: %.0f/100. Sleep %.1fh, activity on track for your goals.", energy, healthSummary.sleepHours),
            category: .health,
            impactScore: min(100, energy),
            source: .onDevice,
            experimentVariant: experimentVariant
        ))

        cards.append(InsightCard(
            title: "Habit odds",
            body: String(format: "Estimated success probability for your focus habit today: %.0f%%.", habitP * 100),
            category: .habits,
            impactScore: habitP * 100,
            source: .onDevice,
            experimentVariant: experimentVariant
        ))

        if let top = topCategory {
            let z = 1.5
            let mom = 0.15
            let recurringShare = min(1.0, Double(recurring.count) / Double(max(1, monthSpend.count)))
            let anomaly = onDevice.spendingAnomalyScore(input: SpendingAnomalyInput(
                categorySpendZScore: z,
                monthOverMonthChange: mom,
                recurringShare: recurringShare
            ))
            cards.append(InsightCard(
                title: "Spending pulse",
                body: "Largest category this month: \(top.key). Consider a weekly cap if this is discretionary.",
                category: .finance,
                impactScore: 40 + anomaly,
                source: .onDevice,
                experimentVariant: experimentVariant
            ))
        }

        if let firstUnused = unused.first {
            let savings = (firstUnused.monthlyEstimate as NSDecimalNumber).stringValue
            cards.append(InsightCard(
                title: "Subscription check",
                body: "No recent charges from \(firstUnused.merchantKey). If you are not using it, canceling could save about \(savings) per month.",
                category: .finance,
                impactScore: 75,
                source: .onDevice,
                experimentVariant: experimentVariant
            ))
        }

        let conflicts = calendar.detectConflicts(in: try calendar.fetchEvents(forDayContaining: today))
        if let c = conflicts.first {
            cards.append(InsightCard(
                title: "Calendar overlap",
                body: "\"\(c.first.title)\" overlaps with \"\(c.second.title)\". Consider shortening or rescheduling one.",
                category: .calendar,
                impactScore: 85,
                source: .onDevice,
                experimentVariant: experimentVariant
            ))
        }

        if includeCloudBriefing {
            let ctx = Self.buildCloudContext(
                health: healthSummary,
                energy: energy,
                meetingDensity: meetingDensity,
                topCategory: topCategory?.key,
                habit: habit
            )
            let cloudResp = try await cloud.crossDomainInsights(context: ctx)
            cards.append(InsightCard(
                title: "Deep insight",
                body: cloudResp.text,
                category: .crossDomain,
                impactScore: 95,
                source: .cloud,
                experimentVariant: experimentVariant
            ))
        }

        let sorted = cards.sorted { $0.impactScore > $1.impactScore }
        insightsSubject.send(sorted)
        return sorted
    }

    private static func buildCloudContext(
        health: DailyHealthSummary,
        energy: Double,
        meetingDensity: Double,
        topCategory: String?,
        habit: HabitInsightSnapshot
    ) -> String {
        """
        Health: steps \(Int(health.stepCount)), sleep \(String(format: "%.1f", health.sleepHours))h, active energy \(Int(health.activeEnergyKilocalories)) kcal, estimated energy score \(Int(energy)).
        Calendar: meeting density \(String(format: "%.0f", meetingDensity * 100))% of workday.
        Money: top spend category \(topCategory ?? "n/a").
        Habits: streak \(habit.streakDays)d, 7d completion \(String(format: "%.0f", habit.completionRate7d * 100))%, preferred slot free: \(habit.preferredSlotFree).
        """
    }

    // MARK: Refresh scheduling

    /// Periodically regenerates insights on the given interval (e.g. 6 hours).
    public func startScheduledRefresh(interval: TimeInterval, habitProvider: @escaping @Sendable () async -> HabitInsightSnapshot) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let habit = await habitProvider()
                _ = try? await self.generateInsights(habit: habit, includeCloudBriefing: false)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stopScheduledRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: A/B testing

    /// Returns a stable variant assignment per user id (or anonymous default).
    public static func insightFormatVariant(userId: String) -> String {
        let h = abs(userId.hashValue) % 2
        return h == 0 ? "compact" : "narrative"
    }

    // MARK: Action tracking

    public func markActedOn(insightId: String) {
        var set = Set(defaults.stringArray(forKey: actedKey) ?? [])
        set.insert(insightId)
        defaults.set(Array(set), forKey: actedKey)
    }

    public func hasUserActed(on insightId: String) -> Bool {
        Set(defaults.stringArray(forKey: actedKey) ?? []).contains(insightId)
    }
}
