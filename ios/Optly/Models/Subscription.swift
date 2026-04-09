import Foundation

struct Subscription: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var provider: String
    var cost: Decimal
    var billingCycle: BillingCycle
    var category: SubscriptionCategory
    var lastUsedAt: Date?
    var usageScore: Int
    var aiRecommendation: AIRecommendation
    var potentialMonthlySavings: Decimal

    enum BillingCycle: String, Codable, CaseIterable {
        case weekly
        case monthly
        case quarterly
        case annual
    }

    enum SubscriptionCategory: String, Codable, CaseIterable {
        case productivity
        case entertainment
        case health
        case finance
        case education
        case utilities
        case other
    }

    enum AIRecommendation: String, Codable, CaseIterable {
        case keep
        case cancel
        case downgrade
    }

    init(
        id: UUID,
        name: String,
        provider: String,
        cost: Decimal,
        billingCycle: BillingCycle,
        category: SubscriptionCategory,
        lastUsedAt: Date?,
        usageScore: Int,
        aiRecommendation: AIRecommendation,
        potentialMonthlySavings: Decimal
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.cost = cost
        self.billingCycle = billingCycle
        self.category = category
        self.lastUsedAt = lastUsedAt
        self.usageScore = usageScore
        self.aiRecommendation = aiRecommendation
        self.potentialMonthlySavings = potentialMonthlySavings
    }
}

// MARK: - Codable (Decimal)

extension Subscription {
    enum CodingKeys: String, CodingKey {
        case id, name, provider, cost, billingCycle, category, lastUsedAt, usageScore, aiRecommendation, potentialMonthlySavings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        provider = try c.decode(String.self, forKey: .provider)
        let costString = try c.decode(String.self, forKey: .cost)
        cost = Decimal(string: costString) ?? 0
        billingCycle = try c.decode(BillingCycle.self, forKey: .billingCycle)
        category = try c.decode(SubscriptionCategory.self, forKey: .category)
        lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        usageScore = try c.decode(Int.self, forKey: .usageScore)
        aiRecommendation = try c.decode(AIRecommendation.self, forKey: .aiRecommendation)
        let savingsString = try c.decode(String.self, forKey: .potentialMonthlySavings)
        potentialMonthlySavings = Decimal(string: savingsString) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(provider, forKey: .provider)
        try c.encode(NSDecimalNumber(decimal: cost).stringValue, forKey: .cost)
        try c.encode(billingCycle, forKey: .billingCycle)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try c.encode(usageScore, forKey: .usageScore)
        try c.encode(aiRecommendation, forKey: .aiRecommendation)
        try c.encode(NSDecimalNumber(decimal: potentialMonthlySavings).stringValue, forKey: .potentialMonthlySavings)
    }
}

// MARK: - Formatting

extension Subscription {
    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

// MARK: - Sample data

extension Subscription {
    static let sample = Subscription(
        id: UUID(),
        name: "CloudNotes Pro",
        provider: "CloudNotes Inc.",
        cost: 9.99,
        billingCycle: .monthly,
        category: .productivity,
        lastUsedAt: Date().addingTimeInterval(-86400 * 2),
        usageScore: 78,
        aiRecommendation: .keep,
        potentialMonthlySavings: 0
    )

    static let sampleCancelCandidate = Subscription(
        id: UUID(),
        name: "MegaStream Premium",
        provider: "MegaStream",
        cost: 15.99,
        billingCycle: .monthly,
        category: .entertainment,
        lastUsedAt: Date().addingTimeInterval(-86400 * 45),
        usageScore: 22,
        aiRecommendation: .cancel,
        potentialMonthlySavings: 15.99
    )

    static let samples: [Subscription] = [sample, sampleCancelCandidate]
}
