//
//  CalendarService.swift
//  Optly
//
//  EventKit access, event fetching, meeting density, and free-slot suggestions.
//

import Foundation
import EventKit
import Combine

// MARK: - Errors

public enum CalendarServiceError: LocalizedError, Sendable {
    case accessDenied
    case accessRestricted
    case storeUnavailable
    case invalidDateRange

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied. Enable it in Settings > Privacy > Calendars."
        case .accessRestricted:
            return "Calendar access is restricted on this device."
        case .storeUnavailable:
            return "The event store is not available."
        case .invalidDateRange:
            return "The requested date range is invalid."
        }
    }
}

// MARK: - Models

public struct CalendarEventSummary: Identifiable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var calendarIdentifier: String
    public var location: String?

    public init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, calendarIdentifier: String, location: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarIdentifier = calendarIdentifier
        self.location = location
    }
}

public struct FocusBlockSuggestion: Sendable, Equatable {
    public var start: Date
    public var end: Date
    public var reason: String

    public init(start: Date, end: Date, reason: String) {
        self.start = start
        self.end = end
        self.reason = reason
    }
}

public struct CalendarConflict: Sendable, Equatable {
    public var first: CalendarEventSummary
    public var second: CalendarEventSummary

    public init(first: CalendarEventSummary, second: CalendarEventSummary) {
        self.first = first
        self.second = second
    }
}

// MARK: - Service

/// Wraps `EKEventStore` with async authorization and scheduling helpers.
public final class CalendarService: @unchecked Sendable {

    private let eventStore: EKEventStore
    private let calendar: Calendar

    private let eventsSubject = CurrentValueSubject<[CalendarEventSummary], Never>([])

    public var eventsPublisher: AnyPublisher<[CalendarEventSummary], Never> {
        eventsSubject.eraseToAnyPublisher()
    }

    public init(eventStore: EKEventStore = EKEventStore(), calendar: Calendar = .current) {
        self.eventStore = eventStore
        self.calendar = calendar
    }

    /// Requests full calendar access (iOS 17+ uses ``EKEventStore/requestFullAccessToEvents()`` when linked against new SDK).
    public func requestAccess() async throws {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            if !granted { throw CalendarServiceError.accessDenied }
        } else {
            let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                eventStore.requestAccess(to: .event) { ok, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ok)
                    }
                }
            }
            if !granted { throw CalendarServiceError.accessDenied }
        }
    }

    /// Events for the calendar day containing `date` (excluding all-day if `includeAllDay` is false).
    public func fetchEvents(forDayContaining date: Date, includeAllDay: Bool = true) throws -> [CalendarEventSummary] {
        guard let interval = calendar.dateInterval(of: .day, for: date) else {
            throw CalendarServiceError.invalidDateRange
        }
        return try fetchEvents(from: interval.start, to: interval.end, includeAllDay: includeAllDay)
    }

    public func fetchUpcomingEvents(from start: Date = Date(), durationDays: Int = 7, includeAllDay: Bool = true) throws -> [CalendarEventSummary] {
        guard let end = calendar.date(byAdding: .day, value: durationDays, to: start) else {
            throw CalendarServiceError.invalidDateRange
        }
        return try fetchEvents(from: start, to: end, includeAllDay: includeAllDay)
    }

    private func fetchEvents(from start: Date, to end: Date, includeAllDay: Bool) throws -> [CalendarEventSummary] {
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        let mapped: [CalendarEventSummary] = events.compactMap { ev in
            if !includeAllDay && ev.isAllDay { return nil }
            return CalendarEventSummary(
                id: ev.eventIdentifier,
                title: ev.title,
                startDate: ev.startDate,
                endDate: ev.endDate,
                isAllDay: ev.isAllDay,
                calendarIdentifier: ev.calendar.calendarIdentifier,
                location: ev.location
            )
        }
        let sorted = mapped.sorted { $0.startDate < $1.startDate }
        eventsSubject.send(sorted)
        return sorted
    }

    /// Meeting density = scheduled minutes / working minutes in the interval (default 9–17 local).
    public func meetingDensity(
        events: [CalendarEventSummary],
        on day: Date,
        workStartHour: Int = 9,
        workEndHour: Int = 17
    ) -> Double {
        guard let dayStart = calendar.dateInterval(of: .day, for: day)?.start else { return 0 }
        var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        components.hour = workStartHour
        components.minute = 0
        guard let workStart = calendar.date(from: components) else { return 0 }
        components.hour = workEndHour
        guard let workEnd = calendar.date(from: components) else { return 0 }
        let workSeconds = workEnd.timeIntervalSince(workStart)
        guard workSeconds > 0 else { return 0 }

        var busy: TimeInterval = 0
        for e in events where !e.isAllDay {
            let s = max(e.startDate, workStart)
            let en = min(e.endDate, workEnd)
            if en > s { busy += en.timeIntervalSince(s) }
        }
        return min(1, busy / workSeconds)
    }

    /// Suggests a focus block after dense meeting clusters (gap ≥ `minimumGapMinutes`).
    public func suggestFocusBlocks(
        events: [CalendarEventSummary],
        on day: Date,
        minimumGapMinutes: Int = 90,
        blockDurationMinutes: Int = 60
    ) -> [FocusBlockSuggestion] {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
        let timed = events.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        var suggestions: [FocusBlockSuggestion] = []
        var cursor = interval.start

        for e in timed {
            let gap = e.startDate.timeIntervalSince(cursor)
            if gap >= Double(minimumGapMinutes * 60) {
                let blockEnd = min(e.startDate, cursor.addingTimeInterval(Double(blockDurationMinutes * 60)))
                if blockEnd.timeIntervalSince(cursor) >= Double(blockDurationMinutes * 60) - 60 {
                    suggestions.append(FocusBlockSuggestion(
                        start: cursor,
                        end: cursor.addingTimeInterval(Double(blockDurationMinutes * 60)),
                        reason: "Open window before \"\(e.title)\""
                    ))
                }
            }
            cursor = max(cursor, e.endDate)
        }

        let endOfDay = interval.end
        if endOfDay.timeIntervalSince(cursor) >= Double(minimumGapMinutes * 60) {
            let blockEnd = cursor.addingTimeInterval(Double(blockDurationMinutes * 60))
            if blockEnd <= endOfDay {
                suggestions.append(FocusBlockSuggestion(start: cursor, end: blockEnd, reason: "Afternoon focus window"))
            }
        }
        return suggestions
    }

    /// Finds the first slot of `durationMinutes` with no overlapping timed events between `searchStart` and `searchEnd`.
    public func optimalSlot(
        durationMinutes: Int,
        searchStart: Date,
        searchEnd: Date,
        existingEvents: [CalendarEventSummary]
    ) -> Date? {
        let timed = existingEvents.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        var cursor = searchStart
        let need = Double(durationMinutes * 60)

        for e in timed {
            if e.startDate.timeIntervalSince(cursor) >= need {
                return cursor
            }
            cursor = max(cursor, e.endDate)
        }
        if searchEnd.timeIntervalSince(cursor) >= need {
            return cursor
        }
        return nil
    }

    public func detectConflicts(in events: [CalendarEventSummary]) -> [CalendarConflict] {
        let timed = events.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        var conflicts: [CalendarConflict] = []
        for i in 0..<timed.count {
            for j in (i + 1)..<timed.count {
                let a = timed[i]
                let b = timed[j]
                if b.startDate >= a.endDate { break }
                if a.endDate > b.startDate && b.startDate < a.endDate {
                    conflicts.append(CalendarConflict(first: a, second: b))
                }
            }
        }
        return conflicts
    }
}
