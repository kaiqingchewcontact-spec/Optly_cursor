//
//  SubscriptionManager.swift
//  Optly
//
//  StoreKit 2 products, purchases, verification, trials, restore, and family sharing.
//

import Foundation
import Combine
import StoreKit

// MARK: - Errors

public enum SubscriptionManagerError: LocalizedError, Sendable {
    case productsUnavailable
    case purchaseFailed(underlying: Error)
    case unverified(Transaction, Error)
    case noActiveSubscription

    public var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            return "Subscription products could not be loaded from the App Store."
        case .purchaseFailed(let e):
            return "Purchase failed: \(e.localizedDescription)"
        case .unverified(_, let err):
            return "Transaction could not be verified: \(err.localizedDescription)"
        case .noActiveSubscription:
            return "There is no active subscription."
        }
    }
}

// MARK: - Product IDs (configure in App Store Connect)

public enum OptlySubscriptionProduct: String, CaseIterable, Sendable {
    case monthly = "com.optly.subscription.monthly"
    case annual = "com.optly.subscription.annual"
}

// MARK: - Subscription state

public struct SubscriptionState: Sendable, Equatable {
    public var productID: String?
    public var isActive: Bool
    public var willAutoRenew: Bool
    public var expirationDate: Date?
    public var isInTrialPeriod: Bool
    public var isInGracePeriod: Bool
    public var ownership: Transaction.OwnershipType?

    public init(
        productID: String? = nil,
        isActive: Bool = false,
        willAutoRenew: Bool = false,
        expirationDate: Date? = nil,
        isInTrialPeriod: Bool = false,
        isInGracePeriod: Bool = false,
        ownership: Transaction.OwnershipType? = nil
    ) {
        self.productID = productID
        self.isActive = isActive
        self.willAutoRenew = willAutoRenew
        self.expirationDate = expirationDate
        self.isInTrialPeriod = isInTrialPeriod
        self.isInGracePeriod = isInGracePeriod
        self.ownership = ownership
    }
}

// MARK: - Manager

/// Loads Optly subscription products, runs purchase flows, and listens for Transaction updates.
public final class SubscriptionManager: @unchecked Sendable {

    private let productIds: [String]
    private var productsCache: [Product] = []
    private let stateSubject = CurrentValueSubject<SubscriptionState, Never>(SubscriptionState())
    private var updatesTask: Task<Void, Never>?

    public var subscriptionStatePublisher: AnyPublisher<SubscriptionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public var currentState: SubscriptionState {
        stateSubject.value
    }

    public init(productIds: [String] = OptlySubscriptionProduct.allCases.map(\.rawValue)) {
        self.productIds = productIds
        startListeningForUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: Products

    /// Fetches subscription products from the App Store (monthly + annual).
    public func loadProducts() async throws -> [Product] {
        let products = try await Product.products(for: productIds)
        guard !products.isEmpty else { throw SubscriptionManagerError.productsUnavailable }
        productsCache = products
        return products
    }

    public func product(for tier: OptlySubscriptionProduct) -> Product? {
        productsCache.first { $0.id == tier.rawValue }
    }

    // MARK: Purchase

    public func purchase(_ product: Product) async throws -> Transaction {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return transaction
            case .userCancelled:
                throw SubscriptionManagerError.purchaseFailed(underlying: NSError(domain: "Optly", code: 0, userInfo: [NSLocalizedDescriptionKey: "User cancelled"]))
            case .pending:
                throw SubscriptionManagerError.purchaseFailed(underlying: NSError(domain: "Optly", code: 1, userInfo: [NSLocalizedDescriptionKey: "Purchase pending"]))
            @unknown default:
                throw SubscriptionManagerError.purchaseFailed(underlying: NSError(domain: "Optly", code: 2, userInfo: nil))
            }
        } catch let e as SubscriptionManagerError {
            throw e
        } catch {
            throw SubscriptionManagerError.purchaseFailed(underlying: error)
        }
    }

    // MARK: Restore

    public func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: Verification

    private func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified(let t, let err):
            throw SubscriptionManagerError.unverified(t, err)
        case .verified(let t):
            return t
        }
    }

    /// Recomputes subscription state from current entitlements and, when available, StoreKit subscription status.
    public func refreshEntitlements() async {
        var best = SubscriptionState()
        let now = Date()

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let tx) = entitlement else { continue }
            guard productIds.contains(tx.productID) else { continue }

            let expiration = tx.expirationDate
            var candidate = SubscriptionState(
                productID: tx.productID,
                isActive: false,
                willAutoRenew: false,
                expirationDate: expiration,
                isInTrialPeriod: false,
                isInGracePeriod: false,
                ownership: tx.ownershipType
            )

            if let exp = expiration, exp > now {
                candidate.isActive = true
            }

            if let status = try? await tx.subscriptionStatus {
                switch status.renewalInfo {
                case .verified(let info):
                    candidate.willAutoRenew = info.willAutoRenew
                    if info.offerType == .introductory {
                        candidate.isInTrialPeriod = true
                    }
                case .unverified:
                    break
                }
                candidate.isInGracePeriod = (status.state == .inGracePeriod)
                let subscribed = status.state == .subscribed
                    || status.state == .inGracePeriod
                    || status.state == .inBillingRetryPeriod
                candidate.isActive = subscribed && (expiration.map { $0 > now } ?? true)
            }

            if (candidate.expirationDate ?? .distantPast) > (best.expirationDate ?? .distantPast) {
                best = candidate
            }
        }

        stateSubject.send(best)
    }

    /// Whether the active entitlement is shared via Family Sharing.
    public var isFamilyShared: Bool {
        currentState.ownership == .familyShared
    }

    // MARK: Trial

    /// Introductory offer eligibility for a product (StoreKit 2).
    public func isEligibleForIntroOffer(for product: Product) async -> Bool {
        await product.subscription?.isEligibleForIntroOffer ?? false
    }

    private func startListeningForUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let tx) = update {
                    await tx.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }
}
