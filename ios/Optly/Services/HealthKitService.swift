//
//  HealthKitService.swift
//  Optly
//
//  HealthKit authorization, queries, energy scoring, and reactive updates.
//

import Foundation
import Combine
import HealthKit

// MARK: - Errors

/// Errors surfaced by ``HealthKitService`` when HealthKit is unavailable or queries fail.
public enum HealthKitServiceError: LocalizedError, Sendable {
    case healthDataUnavailable
    case authorizationDeniedOrRestricted
    case typeNotAvailable(HKObjectType)
    case queryFailed(underlying: Error?)
    case backgroundDeliveryUnsupported

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .authorizationDeniedOrRestricted:
            return "Health access was denied or is restricted. Enable it in Settings > Privacy > Health."
        case .typeNotAvailable(let type):
            return "The requested HealthKit type is not available: \(type)."
        case .queryFailed(let err):
            return err.map { "HealthKit query failed: \($0.localizedDescription)" } ?? "HealthKit query failed."
        case .backgroundDeliveryUnsupported:
            return "Background delivery is not supported for the requested data types."
        }
    }
}

// MARK: - Models

/// Aggregated health metrics for a single calendar day (typically "today").
public struct DailyHealthSummary: Sendable, Equatable {
    public var date: Date
    public var stepCount: Double
    public var sleepHours: Double
    public var restingHeartRateBpm: Double?
    public var activeEnergyKilocalories: Double
    public var workoutMinutes: Double
    public var heartRateVariabilityMs: Double?

    public init(
        date: Date,
        stepCount: Double = 0,
        sleepHours: Double = 0,
        restingHeartRateBpm: Double? = nil,
        activeEnergyKilocalories: Double = 0,
        workoutMinutes: Double = 0,
        heartRateVariabilityMs: Double? = nil
    ) {
        self.date = date
        self.stepCount = stepCount
        self.sleepHours = sleepHours
        self.restingHeartRateBpm = restingHeartRateBpm
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.workoutMinutes = workoutMinutes
        self.heartRateVariabilityMs = heartRateVariabilityMs
    }
}

// MARK: - Service

/// Coordinates HealthKit authorization, statistics queries, energy scoring, and background observers.
///
/// Use ``dailySummaryPublisher`` or ``fetchTodaySummary()`` for today's data. Call ``requestAuthorization()``
/// before reading samples. Enable ``enableBackgroundDelivery()`` for real-time style updates when the app
/// is eligible for background execution.
public final class HealthKitService: NSObject, @unchecked Sendable {

    private let healthStore: HKHealthStore
    private let calendar: Calendar

    private let summarySubject = CurrentValueSubject<DailyHealthSummary?, Never>(nil)
    private let energyScoreSubject = CurrentValueSubject<Double, Never>(0)
    private let authorizationSubject = CurrentValueSubject<Bool, Never>(false)

    private var observerQueries: [HKObserverQuery] = []
    private let observerLock = NSLock()

    /// Publishes the latest daily summary whenever it is refreshed.
    public var dailySummaryPublisher: AnyPublisher<DailyHealthSummary?, Never> {
        summarySubject.eraseToAnyPublisher()
    }

    /// Publishes the computed energy level score (0...100) derived from sleep, activity, and HRV when available.
    public var energyScorePublisher: AnyPublisher<Double, Never> {
        energyScoreSubject.eraseToAnyPublisher()
    }

    /// `true` after successful read authorization for the types Optly uses.
    public var isAuthorizedPublisher: AnyPublisher<Bool, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }

    /// Types Optly reads for summaries and scoring.
    public static var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        if let t = HKQuantityType.quantityType(forIdentifier: .stepCount) { set.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRate) { set.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { set.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { set.insert(t) }
        set.insert(HKObjectType.workoutType())
        return set
    }

    /// Creates a service with injectable ``HKHealthStore`` and calendar (for tests).
    public init(healthStore: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.healthStore = healthStore
        self.calendar = calendar
        super.init()
    }

    deinit {
        stopObserverQueries()
    }

    // MARK: Authorization

    /// Requests read access for steps, sleep, heart rate, resting heart rate, active energy, HRV, and workouts.
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: Self.readTypes)
        authorizationSubject.send(true)
    }

    // MARK: Fetch summary

    /// Fetches aggregated statistics for the given day's interval and updates publishers.
    public func fetchSummary(for day: Date) async throws -> DailyHealthSummary {
        let interval = calendar.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 86400)
        let start = interval.start
        let end = interval.end

        async let steps = quantitySum(.stepCount, unit: .count(), from: start, to: end)
        async let activeEnergy = quantitySum(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
        async let sleepHours = sleepDurationHours(from: start, to: end)
        async let restingHR = quantityAverage(.restingHeartRate, unit: .count().unitDivided(by: .minute()), from: start, to: end)
        async let hrv = quantityAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: start, to: end)
        async let workoutMinutes = workoutDurationMinutes(from: start, to: end)

        let summary = DailyHealthSummary(
            date: start,
            stepCount: try await steps,
            sleepHours: try await sleepHours,
            restingHeartRateBpm: try await restingHR,
            activeEnergyKilocalories: try await activeEnergy,
            workoutMinutes: try await workoutMinutes,
            heartRateVariabilityMs: try await hrv
        )

        summarySubject.send(summary)
        let score = Self.computeEnergyLevelScore(from: summary)
        energyScoreSubject.send(score)
        return summary
    }

    /// Convenience: fetches today's summary in the service's calendar.
    public func fetchTodaySummary() async throws -> DailyHealthSummary {
        try await fetchSummary(for: Date())
    }

    // MARK: Energy score

    /// Computes a 0...100 energy score from sleep duration, activity (steps + active energy + workouts), and HRV.
    ///
    /// Heuristic: balances sleep (target ~7.5h), moderate activity, and higher HRV relative to a baseline.
    public static func computeEnergyLevelScore(from summary: DailyHealthSummary) -> Double {
        let sleepTarget: Double = 7.5
        let sleepScore = min(100, max(0, (summary.sleepHours / sleepTarget) * 100))
        let stepComponent = min(100, (summary.stepCount / 10_000) * 100)
        let energyComponent = min(100, (summary.activeEnergyKilocalories / 500) * 100)
        let workoutComponent = min(100, (summary.workoutMinutes / 45) * 100)
        let activityScore = (stepComponent * 0.35 + energyComponent * 0.35 + workoutComponent * 0.30)

        let hrvScore: Double
        if let hrv = summary.heartRateVariabilityMs, hrv > 0 {
            // Typical resting HRV varies; map 20–80 ms to a reasonable band
            hrvScore = min(100, max(0, ((hrv - 15) / 50) * 100))
        } else {
            hrvScore = 50
        }

        let blended = sleepScore * 0.45 + activityScore * 0.35 + hrvScore * 0.20
        return min(100, max(0, blended))
    }

    // MARK: Background delivery

    /// Enables background delivery for key quantity types so ``refreshOnHealthDataChange()`` can fire.
    public func enableBackgroundDelivery() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        let types: [HKSampleType] = [
            HKQuantityType.quantityType(forIdentifier: .stepCount),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ].compactMap { $0 }

        for type in types {
            do {
                try await healthStore.enableBackgroundDelivery(for: type, frequency: .immediate)
            } catch {
                throw HealthKitServiceError.backgroundDeliveryUnsupported
            }
        }
    }

    /// Installs ``HKObserverQuery`` observers for read types and invokes `handler` when data may have changed.
    public func startObserverQueries(onUpdate: @escaping @Sendable () -> Void) {
        stopObserverQueries()
        observerLock.lock()
        defer { observerLock.unlock() }

        for type in Self.readTypes.compactMap({ $0 as? HKSampleType }) {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
                if error != nil {
                    completionHandler()
                    return
                }
                onUpdate()
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }
    }

    public func stopObserverQueries() {
        observerLock.lock()
        let queries = observerQueries
        observerQueries.removeAll()
        observerLock.unlock()
        queries.forEach { healthStore.stop($0) }
    }

    /// Refreshes today's summary; suitable as the observer callback from ``startObserverQueries(onUpdate:)``.
    public func refreshOnHealthDataChange() {
        Task {
            _ = try? await fetchTodaySummary()
        }
    }

    // MARK: - Private queries

    private func quantitySum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.queryFailed(underlying: nil)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(underlying: error))
                    return
                }
                let sum = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }

    private func quantityAverage(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(underlying: error))
                    return
                }
                let avg = result?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: avg)
            }
            healthStore.execute(query)
        }
    }

    private func sleepDurationHours(from start: Date, to end: Date) async throws -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(underlying: error))
                    return
                }
                guard let categories = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                var asleepSeconds: TimeInterval = 0
                for s in categories {
                    switch s.value {
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                         HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                         HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                         HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        asleepSeconds += s.endDate.timeIntervalSince(s.startDate)
                    default:
                        break
                    }
                }
                continuation.resume(returning: asleepSeconds / 3600)
            }
            healthStore.execute(query)
        }
    }

    private func workoutDurationMinutes(from start: Date, to end: Date) async throws -> Double {
        let type = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(underlying: error))
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                let seconds = workouts.reduce(0) { $0 + $1.duration }
                continuation.resume(returning: seconds / 60)
            }
            healthStore.execute(query)
        }
    }
}
