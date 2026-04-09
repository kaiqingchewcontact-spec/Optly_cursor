//
//  Date+Extensions.swift
//  Optly
//
//  Display formatting, relative time, calendar boundaries, and time-block strings.
//

import Foundation

extension Date {

    // MARK: Display

    /// Short date suitable for headers, locale-aware.
    public func optlyMediumDateString(locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = locale
        f.timeZone = timeZone
        return f.string(from: self)
    }

    /// Time only, e.g. "3:30 PM".
    public func optlyShortTimeString(locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.locale = locale
        f.timeZone = timeZone
        return f.string(from: self)
    }

    // MARK: Relative

    /// "2 hours ago", "in 3 days", using `RelativeDateTimeFormatter`.
    public func optlyRelativeDescription(locale: Locale = .current) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = locale
        f.unitsStyle = .full
        return f.localizedString(for: self, relativeTo: Date())
    }

    // MARK: Calendar boundaries

    public func optlyStartOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    public func optlyStartOfWeek(calendar: Calendar = .current) -> Date {
        let d = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)) ?? self
        return calendar.startOfDay(for: d)
    }

    public func optlyStartOfMonth(calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps) ?? self
    }

    public func optlyEndOfDay(calendar: Calendar = .current) -> Date {
        guard let next = calendar.date(byAdding: .day, value: 1, to: optlyStartOfDay(calendar: calendar)) else { return self }
        return next.addingTimeInterval(-1)
    }

    // MARK: Time blocks

    /// "9:00 AM – 10:30 AM" in the given locale and time zone.
    public func optlyTimeBlockString(end: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let t = optlyShortTimeString(locale: locale, timeZone: timeZone)
        let u = end.optlyShortTimeString(locale: locale, timeZone: timeZone)
        return "\(t) – \(u)"
    }
}
