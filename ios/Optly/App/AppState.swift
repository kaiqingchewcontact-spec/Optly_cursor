import Combine
import Foundation
import SwiftUI

/// Central observable state for the Optly app session, entitlements, and feature rollout.
@MainActor
final class AppState: ObservableObject {
    // MARK: - Session

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var authToken: String?

    // MARK: - Premium & onboarding

    @Published var isPremium: Bool = false
    @Published var hasCompletedOnboarding: Bool = false

    // MARK: - Feature flags

    @Published var featureFlags: FeatureFlags = .default

    // MARK: - Init

    init(
        currentUser: User? = nil,
        isAuthenticated: Bool = false,
        authToken: String? = nil,
        isPremium: Bool = false,
        hasCompletedOnboarding: Bool = false,
        featureFlags: FeatureFlags = .default
    ) {
        self.currentUser = currentUser
        self.isAuthenticated = isAuthenticated
        self.authToken = authToken
        self.isPremium = isPremium
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.featureFlags = featureFlags
        refreshPremiumFromUser()
    }

    // MARK: - Actions

    func signIn(user: User, token: String?) {
        currentUser = user
        authToken = token
        isAuthenticated = true
        refreshPremiumFromUser()
    }

    func signOut() {
        currentUser = nil
        authToken = nil
        isAuthenticated = false
        isPremium = false
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func setOnboardingComplete(_ value: Bool) {
        hasCompletedOnboarding = value
    }

    func updateUser(_ user: User) {
        currentUser = user
        refreshPremiumFromUser()
    }

    func setPremium(_ value: Bool) {
        isPremium = value
        guard var user = currentUser else { return }
        user.isPremium = value
        if !value {
            user.subscriptionTier = .free
        }
        currentUser = user
    }

    private func refreshPremiumFromUser() {
        if let user = currentUser {
            isPremium = user.isPremium || user.subscriptionTier != .free
        } else {
            isPremium = false
        }
    }
}

// MARK: - Feature flags

struct FeatureFlags: Codable, Equatable {
    var aiDailyBriefing: Bool
    var subscriptionOptimizer: Bool
    var focusModes: Bool
    var financeInsights: Bool
    var habitCoaching: Bool

    static let `default` = FeatureFlags(
        aiDailyBriefing: true,
        subscriptionOptimizer: true,
        focusModes: true,
        financeInsights: true,
        habitCoaching: true
    )

    /// Preview / staged rollout preset.
    static let preview = FeatureFlags(
        aiDailyBriefing: true,
        subscriptionOptimizer: true,
        focusModes: true,
        financeInsights: true,
        habitCoaching: true
    )
}
