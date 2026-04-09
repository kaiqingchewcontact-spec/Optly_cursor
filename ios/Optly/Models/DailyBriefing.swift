import Foundation

/// AI-generated daily plan: priorities, health, finance, energy, and suggested time blocks.
struct DailyBriefing: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var greeting: String
    var priorityTasks: [String]
    var healthInsights: [String]
    var financeAlerts: [String]
    var energyLevelPrediction: EnergyLevel
    var recommendedScheduleBlocks: [ScheduleBlock]

    enum EnergyLevel: String, Codable, CaseIterable {
        case low
        case moderate
        case high
        case peak
    }

    struct ScheduleBlock: Identifiable, Codable, Equatable {
        var id: UUID
        var title: String
        var start: Date
        var end: Date
        var category: BlockCategory

        enum BlockCategory: String, Codable, CaseIterable {
            case deepWork
            case health
            case finance
            case habits
            case rest
        }
    }
}

// MARK: - Formatting

extension DailyBriefing {
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()
}

// MARK: - Sample data

extension DailyBriefing {
    private static func block(
        title: String,
        hourStart: Int,
        minuteStart: Int,
        hourEnd: Int,
        minuteEnd: Int,
        category: ScheduleBlock.BlockCategory,
        on day: Date = Date()
    ) -> ScheduleBlock {
        let cal = Calendar.current
        var s = cal.dateComponents([.year, .month, .day], from: day)
        s.hour = hourStart
        s.minute = minuteStart
        var e = cal.dateComponents([.year, .month, .day], from: day)
        e.hour = hourEnd
        e.minute = minuteEnd
        let start = cal.date(from: s) ?? day
        let end = cal.date(from: e) ?? day.addingTimeInterval(3600)
        return ScheduleBlock(
            id: UUID(),
            title: title,
            start: start,
            end: end,
            category: category
        )
    }

    static let sample = DailyBriefing(
        id: UUID(),
        date: Date(),
        greeting: "Good morning — you have a clear window for deep work before noon.",
        priorityTasks: [
            "Finish Q2 budget draft (45 min)",
            "Walk or stretch between meetings",
            "Review subscription renewals due this week"
        ],
        healthInsights: [
            "Sleep consistency improved 12% vs last week.",
            "Aim for 7k steps before 6 PM based on your usual energy dip."
        ],
        financeAlerts: [
            "Two subscriptions renew in 3 days — review Optly’s keep/cancel picks."
        ],
        energyLevelPrediction: .high,
        recommendedScheduleBlocks: [
            block(title: "Deep work: strategy doc", hourStart: 9, minuteStart: 0, hourEnd: 10, minuteEnd: 30, category: .deepWork),
            block(title: "Movement break", hourStart: 10, minuteStart: 30, hourEnd: 10, minuteEnd: 45, category: .health),
            block(title: "Finance: 15-min sweep", hourStart: 13, minuteStart: 0, hourEnd: 13, minuteEnd: 15, category: .finance),
            block(title: "Habit stack: read + journal", hourStart: 21, minuteStart: 0, hourEnd: 21, minuteEnd: 30, category: .habits)
        ]
    )
}
