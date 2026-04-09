//
//  NotificationService.swift
//  Optly
//
//  Remote registration, local scheduling, categories, actions, and preferences.
//

import Foundation
import UserNotifications
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Errors

public enum NotificationServiceError: LocalizedError, Sendable {
    case authorizationDenied
    case schedulingFailed(underlying: Error)
    case invalidTrigger

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notification permission was not granted."
        case .schedulingFailed(let e):
            return "Failed to schedule notification: \(e.localizedDescription)"
        case .invalidTrigger:
            return "The notification trigger configuration is invalid."
        }
    }
}

// MARK: - Preferences

/// User-tunable notification preferences persisted via `UserDefaults`.
public struct NotificationPreferences: Sendable, Codable, Equatable {
    public var dailyBriefingEnabled: Bool
    public var dailyBriefingHour: Int
    public var dailyBriefingMinute: Int
    public var habitRemindersEnabled: Bool
    public var focusBreakRemindersEnabled: Bool
    public var quietHoursStartHour: Int?
    public var quietHoursEndHour: Int?

    public static let `default` = NotificationPreferences(
        dailyBriefingEnabled: true,
        dailyBriefingHour: 8,
        dailyBriefingMinute: 0,
        habitRemindersEnabled: true,
        focusBreakRemindersEnabled: true,
        quietHoursStartHour: 22,
        quietHoursEndHour: 7
    )

    public init(
        dailyBriefingEnabled: Bool,
        dailyBriefingHour: Int,
        dailyBriefingMinute: Int,
        habitRemindersEnabled: Bool,
        focusBreakRemindersEnabled: Bool,
        quietHoursStartHour: Int? = nil,
        quietHoursEndHour: Int? = nil
    ) {
        self.dailyBriefingEnabled = dailyBriefingEnabled
        self.dailyBriefingHour = dailyBriefingHour
        self.dailyBriefingMinute = dailyBriefingMinute
        self.habitRemindersEnabled = habitRemindersEnabled
        self.focusBreakRemindersEnabled = focusBreakRemindersEnabled
        self.quietHoursStartHour = quietHoursStartHour
        self.quietHoursEndHour = quietHoursEndHour
    }
}

// MARK: - Identifiers

public enum OptlyNotificationCategory: String, Sendable {
    case dailyBriefing = "DAILY_BRIEFING"
    case habitReminder = "HABIT_REMINDER"
    case focusBreak = "FOCUS_BREAK"
}

public enum OptlyNotificationAction: String, Sendable {
    case openApp = "OPEN_APP"
    case snooze15 = "SNOOZE_15"
    case markDone = "MARK_DONE"
}

// MARK: - Service

/// Centralizes push registration, local scheduling, categories, and preference-driven behavior.
public final class NotificationService: NSObject, @unchecked Sendable {

    private let center: UNUserNotificationCenter
    private let preferencesKey = "com.optly.notificationPreferences"
    private let defaults: UserDefaults

    private let preferencesSubject: CurrentValueSubject<NotificationPreferences, Never>

    public var preferencesPublisher: AnyPublisher<NotificationPreferences, Never> {
        preferencesSubject.eraseToAnyPublisher()
    }

    public var currentPreferences: NotificationPreferences {
        preferencesSubject.value
    }

    public init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
        let loaded = Self.loadPreferences(from: defaults, key: preferencesKey) ?? .default
        self.preferencesSubject = CurrentValueSubject(loaded)
        super.init()
        center.delegate = self
    }

    // MARK: Authorization

    public func requestAuthorization(options: UNAuthorizationOptions = [.alert, .badge, .sound]) async throws {
        let granted = try await center.requestAuthorization(options: options)
        if !granted { throw NotificationServiceError.authorizationDenied }
    }

    /// Registers for APNs on the main actor when UIKit is available.
    @MainActor
    public func registerForRemoteNotifications() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    // MARK: Categories

    public func registerCategories() {
        let open = UNNotificationAction(
            identifier: OptlyNotificationAction.openApp.rawValue,
            title: "Open",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: OptlyNotificationAction.snooze15.rawValue,
            title: "Snooze 15m",
            options: []
        )
        let done = UNNotificationAction(
            identifier: OptlyNotificationAction.markDone.rawValue,
            title: "Done",
            options: [.authenticationRequired]
        )

        let briefing = UNNotificationCategory(
            identifier: OptlyNotificationCategory.dailyBriefing.rawValue,
            actions: [open],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let habit = UNNotificationCategory(
            identifier: OptlyNotificationCategory.habitReminder.rawValue,
            actions: [done, snooze, open],
            intentIdentifiers: [],
            options: []
        )
        let focus = UNNotificationCategory(
            identifier: OptlyNotificationCategory.focusBreak.rawValue,
            actions: [open, snooze],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([briefing, habit, focus])
    }

    // MARK: Local scheduling

    /// Schedules a repeating daily briefing at the hour/minute from preferences.
    public func scheduleDailyBriefing() async throws {
        guard currentPreferences.dailyBriefingEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: ["daily-briefing"])
            return
        }
        center.removePendingNotificationRequests(withIdentifiers: ["daily-briefing"])

        var dc = DateComponents()
        dc.hour = currentPreferences.dailyBriefingHour
        dc.minute = currentPreferences.dailyBriefingMinute

        let content = UNMutableNotificationContent()
        content.title = "Your Optly briefing"
        content.body = "Tap for today’s health, calendar, and money snapshot."
        content.sound = .default
        content.categoryIdentifier = OptlyNotificationCategory.dailyBriefing.rawValue
        content.userInfo = ["type": "daily_briefing"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-briefing", content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            throw NotificationServiceError.schedulingFailed(underlying: error)
        }
    }

    public func scheduleHabitReminder(identifier: String, title: String, body: String, at date: Date) async throws {
        guard currentPreferences.habitRemindersEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = OptlyNotificationCategory.habitReminder.rawValue
        content.userInfo = ["type": "habit", "habitId": identifier]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: "habit-\(identifier)-\(Int(date.timeIntervalSince1970))", content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            throw NotificationServiceError.schedulingFailed(underlying: error)
        }
    }

    public func scheduleFocusBreak(in minutes: Int, title: String = "Time for a break") async throws {
        guard currentPreferences.focusBreakRemindersEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Stretch, hydrate, or step away for a few minutes."
        content.sound = .default
        content.categoryIdentifier = OptlyNotificationCategory.focusBreak.rawValue
        content.userInfo = ["type": "focus_break"]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, Double(minutes * 60)), repeats: false)
        let request = UNNotificationRequest(identifier: "focus-break-\(UUID().uuidString)", content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            throw NotificationServiceError.schedulingFailed(underlying: error)
        }
    }

    // MARK: Preferences persistence

    public func updatePreferences(_ prefs: NotificationPreferences) {
        preferencesSubject.send(prefs)
        if let data = try? JSONEncoder().encode(prefs) {
            defaults.set(data, forKey: preferencesKey)
        }
        Task {
            try? await scheduleDailyBriefing()
        }
    }

    private static func loadPreferences(from defaults: UserDefaults, key: String) -> NotificationPreferences? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NotificationPreferences.self, from: data)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Host app can observe action identifiers via notification center or callbacks.
        _ = response.actionIdentifier
    }
}
