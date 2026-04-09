//
//  FinanceService.swift
//  Optly
//
//  Plaid Link orchestration, transaction sync, categorization, and savings insights.
//

import Foundation
import Combine
import Security

// MARK: - Errors

/// Errors for finance operations including token storage and network failures.
public enum FinanceServiceError: LocalizedError, Sendable {
    case notConfigured
    case linkCancelled
    case linkFailed(reason: String)
    case tokenMissing
    case tokenSaveFailed(status: OSStatus)
    case network(underlying: Error)
    case decodingFailed
    case mockDataUnavailable

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Finance service is not configured (missing Plaid credentials or base URL)."
        case .linkCancelled:
            return "Plaid Link was cancelled."
        case .linkFailed(let r):
            return "Plaid Link failed: \(r)"
        case .tokenMissing:
            return "No stored Plaid access token. Connect an account first."
        case .tokenSaveFailed(let s):
            return "Failed to save token securely (OSStatus \(s))."
        case .network(let e):
            return "Network error: \(e.localizedDescription)"
        case .decodingFailed:
            return "Could not decode finance API response."
        case .mockDataUnavailable:
            return "Mock finance data is not available."
        }
    }
}

// MARK: - Models

public struct PlaidTransaction: Identifiable, Sendable, Equatable, Codable {
    public var id: String
    public var accountId: String
    public var amount: Decimal
    public var isoCurrencyCode: String?
    public var name: String
    public var merchantName: String?
    public var category: [String]?
    public var personalFinanceCategory: String?
    public var date: Date
    public var pending: Bool

    public init(
        id: String,
        accountId: String,
        amount: Decimal,
        isoCurrencyCode: String? = nil,
        name: String,
        merchantName: String? = nil,
        category: [String]? = nil,
        personalFinanceCategory: String? = nil,
        date: Date,
        pending: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.amount = amount
        self.isoCurrencyCode = isoCurrencyCode
        self.name = name
        self.merchantName = merchantName
        self.category = category
        self.personalFinanceCategory = personalFinanceCategory
        self.date = date
        self.pending = pending
    }
}

public struct RecurringCharge: Sendable, Equatable {
    public var merchantKey: String
    public var averageAmount: Decimal
    public var frequencyDays: Double
    public var lastChargeDate: Date
    public var category: String?

    public init(merchantKey: String, averageAmount: Decimal, frequencyDays: Double, lastChargeDate: Date, category: String? = nil) {
        self.merchantKey = merchantKey
        self.averageAmount = averageAmount
        self.frequencyDays = frequencyDays
        self.lastChargeDate = lastChargeDate
        self.category = category
    }
}

public struct SubscriptionCandidate: Identifiable, Sendable, Equatable {
    public var id: String { merchantKey }
    public var merchantKey: String
    public var monthlyEstimate: Decimal
    public var lastSeen: Date
    public var isLikelyActive: Bool
    public var monthsSinceLastCharge: Int

    public init(merchantKey: String, monthlyEstimate: Decimal, lastSeen: Date, isLikelyActive: Bool, monthsSinceLastCharge: Int) {
        self.merchantKey = merchantKey
        self.monthlyEstimate = monthlyEstimate
        self.lastSeen = lastSeen
        self.isLikelyActive = isLikelyActive
        self.monthsSinceLastCharge = monthsSinceLastCharge
    }
}

public struct SavingsRecommendation: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var detail: String
    public var estimatedMonthlySavings: Decimal
    public var priority: Int

    public init(id: String = UUID().uuidString, title: String, detail: String, estimatedMonthlySavings: Decimal, priority: Int) {
        self.id = id
        self.title = title
        self.detail = detail
        self.estimatedMonthlySavings = estimatedMonthlySavings
        self.priority = priority
    }
}

// MARK: - Plaid Link bridge

/// Abstraction over Plaid Link UI so the app can swap LinkKit vs mock in tests.
public protocol PlaidLinkPresenting: AnyObject {
    func presentLink(token: String, onSuccess: @escaping (String) -> Void, onExit: @escaping (FinanceServiceError?) -> Void)
}

/// Manages Plaid Link token exchange and presentation. Wire ``presenting`` to a view controller that hosts LinkKit.
public final class PlaidLinkManager: @unchecked Sendable {

    public weak var presenting: PlaidLinkPresenting?

    private let linkTokenProvider: @Sendable () async throws -> String

    public init(linkTokenProvider: @escaping @Sendable () async throws -> String) {
        self.linkTokenProvider = linkTokenProvider
    }

    /// Fetches a link token from your backend and presents Plaid Link.
    public func startLinkFlow() async throws -> String {
        let token = try await linkTokenProvider()
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let presenter = self?.presenting else {
                    continuation.resume(throwing: FinanceServiceError.notConfigured)
                    return
                }
                presenter.presentLink(token: token, onSuccess: { publicToken in
                    continuation.resume(returning: publicToken)
                }, onExit: { err in
                    if let err {
                        continuation.resume(throwing: err)
                    } else {
                        continuation.resume(throwing: FinanceServiceError.linkCancelled)
                    }
                })
            }
        }
    }
}

// MARK: - Keychain token storage

/// Stores Plaid access tokens in the Keychain (generic password item).
public struct SecureTokenStore: Sendable {
    private let service: String
    private let account: String

    public init(service: String = "com.optly.finance", account: String = "plaid_access_token") {
        self.service = service
        self.account = account
    }

    public func saveToken(_ token: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: token
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw FinanceServiceError.tokenSaveFailed(status: status) }
    }

    public func readToken() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw FinanceServiceError.tokenMissing
        }
        return data
    }

    public func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Finance service

/// High-level finance API: transactions, recurring detection, subscriptions, and recommendations.
///
/// Set ``isMockMode`` to `true` for offline development; implement ``fetchTransactionsFromBackend(start:end:)``
/// to call your server which exchanges the public token and proxies Plaid.
public final class FinanceService: @unchecked Sendable {

    public var isMockMode: Bool
    public let linkManager: PlaidLinkManager
    /// When set, used instead of the default mock / unconfigured path to load transactions from your backend.
    public var transactionFetcher: (@Sendable (Date, Date) async throws -> [PlaidTransaction])?
    private let tokenStore: SecureTokenStore
    private let calendar: Calendar

    private let transactionsSubject = CurrentValueSubject<[PlaidTransaction], Never>([])

    /// Reactive stream of the last fetched transaction list.
    public var transactionsPublisher: AnyPublisher<[PlaidTransaction], Never> {
        transactionsSubject.eraseToAnyPublisher()
    }

    public init(
        linkManager: PlaidLinkManager,
        tokenStore: SecureTokenStore = SecureTokenStore(),
        calendar: Calendar = .current,
        isMockMode: Bool = false
    ) {
        self.linkManager = linkManager
        self.tokenStore = tokenStore
        self.calendar = calendar
        self.isMockMode = isMockMode
    }

    /// Persists access token (UTF-8) after your backend exchanges the public token.
    public func storeAccessToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { throw FinanceServiceError.tokenSaveFailed(status: errSecParam) }
        try tokenStore.saveToken(data)
    }

    public func clearAccessToken() {
        tokenStore.deleteToken()
    }

    private func currentAccessToken() throws -> String {
        let data = try tokenStore.readToken()
        guard let s = String(data: data, encoding: .utf8) else { throw FinanceServiceError.tokenMissing }
        return s
    }

    /// Resolves transactions via ``transactionFetcher``, mock data, or throws if unconfigured.
    public func fetchTransactionsFromBackend(start: Date, end: Date) async throws -> [PlaidTransaction] {
        if let fetcher = transactionFetcher {
            return try await fetcher(start, end)
        }
        if isMockMode {
            return Self.mockTransactions(from: start, to: end)
        }
        _ = try currentAccessToken()
        throw FinanceServiceError.notConfigured
    }

    public func fetchTransactions(start: Date, end: Date) async throws -> [PlaidTransaction] {
        let list = try await fetchTransactionsFromBackend(start: start, end: end)
        transactionsSubject.send(list)
        return list
    }

    /// Groups negative (outflow) transactions by primary category for the calendar month containing `date`.
    public func monthlySpendByCategory(forMonthContaining date: Date) async throws -> [String: Decimal] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [:] }
        let txs = try await fetchTransactions(start: interval.start, end: interval.end)
        var map: [String: Decimal] = [:]
        for t in txs where t.amount > 0 {
            let cat = t.personalFinanceCategory ?? t.category?.first ?? "Uncategorized"
            map[cat, default: 0] += t.amount
        }
        return map
    }

    public func detectRecurringCharges(in transactions: [PlaidTransaction]) -> [RecurringCharge] {
        let outflows = transactions.filter { $0.amount > 0 && !$0.pending }
        let grouped = Dictionary(grouping: outflows) { $0.merchantName ?? $0.name }
        var result: [RecurringCharge] = []
        for (key, txs) in grouped where txs.count >= 2 {
            let sorted = txs.sorted { $0.date < $1.date }
            guard sorted.count >= 2 else { continue }
            var gaps: [TimeInterval] = []
            for i in 1..<sorted.count {
                gaps.append(sorted[i].date.timeIntervalSince(sorted[i - 1].date))
            }
            let avgGap = gaps.reduce(0, +) / Double(gaps.count)
            let amounts = sorted.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
            let avgAmount = amounts.reduce(0, +) / Double(amounts.count)
            result.append(RecurringCharge(
                merchantKey: key,
                averageAmount: Decimal(avgAmount),
                frequencyDays: avgGap / 86400,
                lastChargeDate: sorted.last!.date,
                category: sorted.last?.personalFinanceCategory ?? sorted.last?.category?.first
            ))
        }
        return result.sorted { $0.lastChargeDate > $1.lastChargeDate }
    }

    public func detectSubscriptions(recurring: [RecurringCharge], referenceDate: Date = Date()) -> [SubscriptionCandidate] {
        recurring.compactMap { r in
            let daysBetween = max(1, r.frequencyDays)
            let monthly: Decimal
            if daysBetween <= 35 {
                monthly = r.averageAmount
            } else {
                monthly = r.averageAmount * Decimal(30 / daysBetween)
            }
            let monthsSince = calendar.dateComponents([.month], from: r.lastChargeDate, to: referenceDate).month ?? 0
            let active = monthsSince <= 2
            return SubscriptionCandidate(
                merchantKey: r.merchantKey,
                monthlyEstimate: monthly,
                lastSeen: r.lastChargeDate,
                isLikelyActive: active,
                monthsSinceLastCharge: max(0, monthsSince)
            )
        }
    }

    /// Subscriptions with no recent charges but still flagged as active elsewhere can be surfaced as unused candidates.
    public func unusedSubscriptions(_ candidates: [SubscriptionCandidate]) -> [SubscriptionCandidate] {
        candidates.filter { !$0.isLikelyActive && $0.monthsSinceLastCharge >= 2 }
    }

    public func savingsRecommendations(
        subscriptions: [SubscriptionCandidate],
        monthlyByCategory: [String: Decimal]
    ) -> [SavingsRecommendation] {
        var recs: [SavingsRecommendation] = []
        for sub in unusedSubscriptions(subscriptions) {
            recs.append(SavingsRecommendation(
                title: "Review \(sub.merchantKey)",
                detail: "No charges in \(sub.monthsSinceLastCharge) months. Cancel if you no longer use this service.",
                estimatedMonthlySavings: sub.monthlyEstimate,
                priority: 90
            ))
        }
        if let top = monthlyByCategory.max(by: { $0.value < $1.value }) {
            recs.append(SavingsRecommendation(
                title: "Trim \(top.key) spending",
                detail: "Your largest category this month is \(top.key). Set a weekly cap or pause discretionary subscriptions.",
                estimatedMonthlySavings: top.value * Decimal(0.1),
                priority: 60
            ))
        }
        return recs.sorted { $0.priority > $1.priority }
    }

    // MARK: Mock data

    private static func mockTransactions(from start: Date, to end: Date) -> [PlaidTransaction] {
        let netflix = PlaidTransaction(
            id: "mock-1",
            accountId: "acc1",
            amount: Decimal(string: "15.99")!,
            name: "NETFLIX.COM",
            merchantName: "Netflix",
            personalFinanceCategory: "ENTERTAINMENT",
            date: start.addingTimeInterval(86400),
            pending: false
        )
        let gym = PlaidTransaction(
            id: "mock-2",
            accountId: "acc1",
            amount: Decimal(string: "49.00")!,
            name: "GYM MEMBERSHIP",
            merchantName: "City Gym",
            personalFinanceCategory: "PERSONAL_CARE",
            date: start.addingTimeInterval(172800),
            pending: false
        )
        return [netflix, gym].filter { $0.date >= start && $0.date <= end }
    }
}
