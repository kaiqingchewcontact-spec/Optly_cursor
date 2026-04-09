import Foundation

struct InsightCard: Identifiable, Codable, Equatable {
    var id: UUID
    var type: InsightType
    var title: String
    var description: String
    var impactScore: Int
    var actionButtonText: String
    var associatedData: [String: String]
    var priority: Priority

    enum InsightType: String, Codable, CaseIterable {
        case savings
        case health
        case productivity
        case habit
    }

    enum Priority: String, Codable, CaseIterable, Comparable {
        case low
        case medium
        case high
        case urgent

        private var sortOrder: Int {
            switch self {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            case .urgent: return 3
            }
        }

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}

// MARK: - Sample data

extension InsightCard {
    static let sample = InsightCard(
        id: UUID(),
        type: .savings,
        title: "Trim duplicate subscriptions",
        description: "You’re paying for two similar cloud storage plans. Consolidating could save about $12 per month.",
        impactScore: 78,
        actionButtonText: "Review subscriptions",
        associatedData: [
            "subscriptionIds": "uuid-1,uuid-2",
            "estimatedMonthlySavings": "12.00",
            "currency": "USD"
        ],
        priority: .high
    )

    static let samples: [InsightCard] = [
        sample,
        InsightCard(
            id: UUID(),
            type: .health,
            title: "Protect your afternoon focus",
            description: "Your energy tends to dip around 2 PM. A 10-minute walk before then improved focus scores by 14% last week.",
            impactScore: 64,
            actionButtonText: "Schedule walk",
            associatedData: ["windowStart": "13:30", "windowEnd": "14:30"],
            priority: .medium
        ),
        InsightCard(
            id: UUID(),
            type: .habit,
            title: "Stack your finance habit",
            description: "Pair “weekly finance review” with Sunday coffee for a stronger cue.",
            impactScore: 55,
            actionButtonText: "Edit habit",
            associatedData: ["habitId": "sample-habit-uuid"],
            priority: .low
        )
    ]
}
