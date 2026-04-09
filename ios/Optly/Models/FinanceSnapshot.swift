import Foundation

struct FinanceSnapshot: Identifiable, Codable, Equatable {
    var id: UUID
    var monthStart: Date
    var monthlyIncome: Decimal
    var expensesByCategory: [ExpenseCategory: Decimal]
    var subscriptionsTotal: Decimal
    var savingsRate: Double
    var cashFlowPrediction: CashFlowPrediction
    var aiSavingsSuggestions: [String]

    enum ExpenseCategory: String, Codable, CaseIterable, Hashable {
        case housing
        case food
        case transport
        case subscriptions
        case health
        case entertainment
        case savings
        case other
    }

    struct CashFlowPrediction: Codable, Equatable {
        var nextMonthNet: Decimal
        var confidence: Double
        var notes: String

        init(nextMonthNet: Decimal, confidence: Double, notes: String) {
            self.nextMonthNet = nextMonthNet
            self.confidence = confidence
            self.notes = notes
        }
    }

    init(
        id: UUID,
        monthStart: Date,
        monthlyIncome: Decimal,
        expensesByCategory: [ExpenseCategory: Decimal],
        subscriptionsTotal: Decimal,
        savingsRate: Double,
        cashFlowPrediction: CashFlowPrediction,
        aiSavingsSuggestions: [String]
    ) {
        self.id = id
        self.monthStart = monthStart
        self.monthlyIncome = monthlyIncome
        self.expensesByCategory = expensesByCategory
        self.subscriptionsTotal = subscriptionsTotal
        self.savingsRate = savingsRate
        self.cashFlowPrediction = cashFlowPrediction
        self.aiSavingsSuggestions = aiSavingsSuggestions
    }
}

// MARK: - Codable (Decimal & Dictionary)

extension FinanceSnapshot {
    enum CodingKeys: String, CodingKey {
        case id, monthStart, monthlyIncome, expensesByCategory, subscriptionsTotal, savingsRate, cashFlowPrediction, aiSavingsSuggestions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        monthStart = try c.decode(Date.self, forKey: .monthStart)
        let incomeStr = try c.decode(String.self, forKey: .monthlyIncome)
        monthlyIncome = Decimal(string: incomeStr) ?? 0
        let pairs = try c.decode([ExpensePair].self, forKey: .expensesByCategory)
        expensesByCategory = Dictionary(uniqueKeysWithValues: pairs.map { ($0.category, $0.amount) })
        let subStr = try c.decode(String.self, forKey: .subscriptionsTotal)
        subscriptionsTotal = Decimal(string: subStr) ?? 0
        savingsRate = try c.decode(Double.self, forKey: .savingsRate)
        cashFlowPrediction = try c.decode(CashFlowPrediction.self, forKey: .cashFlowPrediction)
        aiSavingsSuggestions = try c.decode([String].self, forKey: .aiSavingsSuggestions)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(monthStart, forKey: .monthStart)
        try c.encode(NSDecimalNumber(decimal: monthlyIncome).stringValue, forKey: .monthlyIncome)
        let pairs = expensesByCategory.map { ExpensePair(category: $0.key, amount: $0.value) }
        try c.encode(pairs.sorted { $0.category.rawValue < $1.category.rawValue }, forKey: .expensesByCategory)
        try c.encode(NSDecimalNumber(decimal: subscriptionsTotal).stringValue, forKey: .subscriptionsTotal)
        try c.encode(savingsRate, forKey: .savingsRate)
        try c.encode(cashFlowPrediction, forKey: .cashFlowPrediction)
        try c.encode(aiSavingsSuggestions, forKey: .aiSavingsSuggestions)
    }

    private struct ExpensePair: Codable, Equatable {
        var category: ExpenseCategory
        var amount: Decimal

        enum CodingKeys: String, CodingKey {
            case category, amount
        }

        init(category: ExpenseCategory, amount: Decimal) {
            self.category = category
            self.amount = amount
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            category = try c.decode(ExpenseCategory.self, forKey: .category)
            let s = try c.decode(String.self, forKey: .amount)
            amount = Decimal(string: s) ?? 0
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(category, forKey: .category)
            try c.encode(NSDecimalNumber(decimal: amount).stringValue, forKey: .amount)
        }
    }
}

// MARK: - Codable for CashFlowPrediction (Decimal)

extension FinanceSnapshot.CashFlowPrediction {
    enum CodingKeys: String, CodingKey {
        case nextMonthNet, confidence, notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let netStr = try c.decode(String.self, forKey: .nextMonthNet)
        nextMonthNet = Decimal(string: netStr) ?? 0
        confidence = try c.decode(Double.self, forKey: .confidence)
        notes = try c.decode(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(NSDecimalNumber(decimal: nextMonthNet).stringValue, forKey: .nextMonthNet)
        try c.encode(confidence, forKey: .confidence)
        try c.encode(notes, forKey: .notes)
    }
}

// MARK: - Formatting

extension FinanceSnapshot {
    static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()
}

// MARK: - Sample data

extension FinanceSnapshot {
    static let sample = FinanceSnapshot(
        id: UUID(),
        monthStart: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date(),
        monthlyIncome: 6_500,
        expensesByCategory: [
            .housing: 1_800,
            .food: 520,
            .transport: 280,
            .subscriptions: 87,
            .health: 120,
            .entertainment: 200,
            .savings: 800,
            .other: 150
        ],
        subscriptionsTotal: 87,
        savingsRate: 0.18,
        cashFlowPrediction: CashFlowPrediction(
            nextMonthNet: 1_420,
            confidence: 0.82,
            notes: "Based on last 3 months of income and recurring bills."
        ),
        aiSavingsSuggestions: [
            "Cancel or pause one low-usage streamer to add ~$16/mo to savings.",
            "Shift grocery shop to mid-week when your spend tends to be lower."
        ]
    )
}
