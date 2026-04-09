import Foundation

struct Habit: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var category: HabitCategory
    var frequency: HabitFrequency
    var streak: Int
    var completions: [Date]
    var aiSuggestedAdjustments: [String]
    var goalTarget: Int
    var progressPercentage: Double

    enum HabitCategory: String, Codable, CaseIterable {
        case health
        case productivity
        case finance
        case wellness
    }

    enum HabitFrequency: String, Codable, CaseIterable {
        case daily
        case weekdays
        case weekly
        case custom
    }
}

// MARK: - Formatting

extension Habit {
    static let completionFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

// MARK: - Sample data

extension Habit {
    static let sample = Habit(
        id: UUID(),
        name: "Morning mobility",
        category: .health,
        frequency: .daily,
        streak: 12,
        completions: (0..<7).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())
        },
        aiSuggestedAdjustments: [
            "Try 8 minutes instead of 15 on low-energy days to protect the streak.",
            "Pair with your first coffee for stronger anchoring."
        ],
        goalTarget: 30,
        progressPercentage: 0.4
    )

    static let samples: [Habit] = [
        sample,
        Habit(
            id: UUID(),
            name: "Weekly finance review",
            category: .finance,
            frequency: .weekly,
            streak: 4,
            completions: [Date().addingTimeInterval(-86400 * 7), Date().addingTimeInterval(-86400 * 14)],
            aiSuggestedAdjustments: ["Schedule a fixed Sunday 10:00 slot."],
            goalTarget: 52,
            progressPercentage: 0.08
        )
    ]
}
