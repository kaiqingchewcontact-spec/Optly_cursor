import Foundation

struct User: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var email: String
    var name: String
    var isPremium: Bool
    var subscriptionTier: SubscriptionTier
    var trial: TrialInfo?
    var preferences: UserPreferences
    var createdAt: Date
    var updatedAt: Date

    enum SubscriptionTier: String, Codable, CaseIterable {
        case free
        case monthly
        case annual
    }

    struct TrialInfo: Codable, Equatable, Hashable {
        var startedAt: Date
        var endsAt: Date
        var isActive: Bool
    }

    struct UserPreferences: Codable, Equatable, Hashable {
        var notificationsEnabled: Bool
        var morningBriefingHour: Int
        var weekStartsOnMonday: Bool
        var currencyCode: String
    }
}

// MARK: - Formatting

extension User {
    static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

// MARK: - Sample data

extension User {
    static let sample = User(
        id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
        email: "alex@example.com",
        name: "Alex Rivera",
        isPremium: true,
        subscriptionTier: .monthly,
        trial: TrialInfo(
            startedAt: Date().addingTimeInterval(-86400 * 5),
            endsAt: Date().addingTimeInterval(86400 * 2),
            isActive: true
        ),
        preferences: UserPreferences(
            notificationsEnabled: true,
            morningBriefingHour: 7,
            weekStartsOnMonday: true,
            currencyCode: "USD"
        ),
        createdAt: Date().addingTimeInterval(-86400 * 120),
        updatedAt: Date()
    )

    static let sampleFree = User(
        id: UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")!,
        email: "sam@example.com",
        name: "Sam Chen",
        isPremium: false,
        subscriptionTier: .free,
        trial: nil,
        preferences: UserPreferences(
            notificationsEnabled: false,
            morningBriefingHour: 8,
            weekStartsOnMonday: true,
            currencyCode: "USD"
        ),
        createdAt: Date().addingTimeInterval(-86400 * 14),
        updatedAt: Date()
    )
}
