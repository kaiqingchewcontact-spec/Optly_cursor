import SwiftUI

private enum SubscriptionFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case atRisk = "At Risk"
    case cancelled = "Cancelled"

    var id: String { rawValue }
}

private enum UsageTier {
    case active   // green
    case low      // yellow
    case unused   // red

    var color: Color {
        switch self {
        case .active: return .green
        case .low: return .yellow
        case .unused: return .red
        }
    }

    var label: String {
        switch self {
        case .active: return "Active use"
        case .low: return "Low use"
        case .unused: return "Unused"
        }
    }
}

private struct TrackedSubscription: Identifiable {
    let id = UUID()
    var name: String
    var monthlyPrice: Decimal
    var tier: UsageTier
    var recommendation: String? // e.g. "Cancel", "Downgrade"
}

struct SubscriptionsView: View {
    @State private var filter: SubscriptionFilter = .all
    @State private var potentialSavingsDisplay: Int = 0
    private let potentialSavingsTarget = 186

    private let subscriptions: [TrackedSubscription] = [
        .init(name: "Studio Pro", monthlyPrice: 29.99, tier: .active, recommendation: nil),
        .init(name: "Cloud Drive Plus", monthlyPrice: 9.99, tier: .low, recommendation: "Downgrade"),
        .init(name: "Fitness+", monthlyPrice: 9.99, tier: .unused, recommendation: "Cancel"),
        .init(name: "News Reader", monthlyPrice: 4.99, tier: .low, recommendation: nil),
        .init(name: "VPN Elite", monthlyPrice: 12.99, tier: .active, recommendation: nil)
    ]

    private var totalMonthly: Decimal {
        subscriptions.reduce(0) { $0 + $1.monthlyPrice }
    }

    private var filtered: [TrackedSubscription] {
        switch filter {
        case .all:
            return subscriptions
        case .active:
            return subscriptions.filter { $0.tier == .active }
        case .atRisk:
            return subscriptions.filter { $0.tier == .low || $0.tier == .unused }
        case .cancelled:
            return []
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                totalSpendCard
                savingsHighlightCard
                filterChips
                scanButton
                subscriptionList
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            potentialSavingsDisplay = 0
            withAnimation(.easeOut(duration: 1.2)) {
                potentialSavingsDisplay = potentialSavingsTarget
            }
        }
    }

    private var totalSpendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total monthly spend")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(totalMonthly, format: .currency(code: "USD"))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.Optly.teal)
                Text("Tracked across \(subscriptions.count) services")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var savingsHighlightCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.Optly.teal.opacity(0.35), .Optly.indigo.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(.Optly.teal)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Potential savings")
                    .font(.subheadline.weight(.semibold))
                Text("$\(potentialSavingsDisplay)")
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(
                        LinearGradient(colors: [.Optly.teal, .Optly.indigo], startPoint: .leading, endPoint: .trailing)
                    )
                Text("Per month if you act on AI recommendations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.Optly.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.Optly.teal.opacity(0.5), .Optly.purple.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SubscriptionFilter.allCases) { f in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            filter = f
                        }
                    } label: {
                        Text(f.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundStyle(filter == f ? Color.white : Color.primary)
                            .background {
                                if filter == f {
                                    Capsule()
                                        .fill(LinearGradient(colors: [.Optly.indigo, .Optly.purple], startPoint: .leading, endPoint: .trailing))
                                } else {
                                    Capsule()
                                        .fill(Color.Optly.elevated)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var scanButton: some View {
        Button {
            // Plaid connection
        } label: {
            Label("Scan accounts", systemImage: "link.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.Optly.indigo)
    }

    private var subscriptionList: some View {
        LazyVStack(spacing: 12) {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "tray",
                    description: Text("Try another filter or connect accounts to find subscriptions.")
                )
                .padding(.vertical, 24)
            } else {
                ForEach(filtered) { sub in
                    subscriptionRow(sub)
                }
            }
        }
    }

    private func subscriptionRow(_ sub: TrackedSubscription) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sub.name)
                        .font(.headline)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(sub.tier.color)
                            .frame(width: 8, height: 8)
                        Text(sub.tier.label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(sub.monthlyPrice, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.caption)
                    .foregroundStyle(.Optly.purple)
                Text(aiLine(for: sub))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let rec = sub.recommendation {
                    Text(rec)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(rec == "Cancel" ? Color.red.opacity(0.15) : Color.Optly.orange.opacity(0.18), in: Capsule())
                        .foregroundStyle(rec == "Cancel" ? Color.red : Color.Optly.orange)
                }
            }
        }
        .padding(16)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func aiLine(for sub: TrackedSubscription) -> String {
        switch sub.tier {
        case .active:
            return "Usage aligns with value—keep monitoring renewal date."
        case .low:
            return "Usage dropped 38% vs. last quarter—good downgrade candidate."
        case .unused:
            return "No opens in 45 days—safe to cancel if not needed for tax docs."
        }
    }
}

#Preview("Subscriptions") {
    NavigationStack {
        SubscriptionsView()
    }
}
