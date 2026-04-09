import SwiftUI

private struct BudgetCategory: Identifiable {
    let id = UUID()
    var name: String
    var spent: Double
    var budget: Double

    var progress: Double {
        guard budget > 0 else { return 0 }
        return min(spent / budget, 1)
    }
}

private struct MicroInvestCard: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var amountLabel: String
}

struct FinanceView: View {
    private let income: Double = 8_200
    private let expenses: Double = 5_450

    private let budgets: [BudgetCategory] = [
        .init(name: "Housing", spent: 2_100, budget: 2_200),
        .init(name: "Food", spent: 620, budget: 700),
        .init(name: "Transport", spent: 280, budget: 350),
        .init(name: "Fun", spent: 410, budget: 300)
    ]

    private let savingsTips: [String] = [
        "Shift one grocery run to a list-based shop—similar users saved ~$45/mo.",
        "Your utilities drifted 8%—a quick rate check often recovers $10–20/mo.",
        "Round-ups to savings could capture ~$38/mo based on recent card spend."
    ]

    private let microCards: [MicroInvestCard] = [
        .init(title: "Spare change sweep", detail: "Invests card round-ups when under daily spend cap.", amountLabel: "~$38/mo"),
        .init(title: "Cash buffer ladder", detail: "Keeps 1 month expenses in HYSA, remainder in index ETF.", amountLabel: "Low risk")
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                monthlyOverviewCard
                chartPlaceholder
                sectionTitle("Budget categories")
                budgetSection
                sectionTitle("AI savings ideas")
                savingsList
                sectionTitle("Micro-investments")
                microInvestSection
                exportButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Finance")
        .navigationBarTitleDisplayMode(.large)
    }

    private var monthlyOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Income", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.Optly.teal)
                    Text(income, format: .currency(code: "USD"))
                        .font(.title2.weight(.bold))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label("Expenses", systemImage: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.Optly.orange)
                    Text(expenses, format: .currency(code: "USD"))
                        .font(.title2.weight(.bold))
                }
                Spacer(minLength: 0)
            }

            let net = income - expenses
            HStack {
                Text("Net")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(net, format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundStyle(net >= 0 ? Color.Optly.teal : Color.Optly.orange)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.Optly.indigo.opacity(0.3), .Optly.teal.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }

    private var chartPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cash flow")
                .font(.headline)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(colors: [.Optly.indigo, .Optly.purple], startPoint: .leading, endPoint: .trailing)
                            )
                        Text("Chart area — income vs. expenses over time")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
        }
        .padding(18)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
    }

    private var budgetSection: some View {
        VStack(spacing: 14) {
            ForEach(budgets) { cat in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(cat.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(cat.spent, format: .currency(code: "USD"))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("/")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(cat.budget, format: .currency(code: "USD"))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: cat.progress > 1 ? [.Optly.orange, .red] : [.Optly.indigo, .Optly.teal],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(cat.progress, 1))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(14)
                .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var savingsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(savingsTips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.max.fill")
                        .foregroundStyle(.Optly.orange)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.Optly.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var microInvestSection: some View {
        VStack(spacing: 12) {
            ForEach(microCards) { card in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(card.title)
                            .font(.headline)
                        Spacer()
                        Text(card.amountLabel)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.Optly.teal.opacity(0.15), in: Capsule())
                            .foregroundStyle(.Optly.teal)
                    }
                    Text(card.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }

    private var exportButton: some View {
        Button {
            // Export report
        } label: {
            Label("Export monthly report", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.bordered)
        .tint(.Optly.indigo)
    }
}

#Preview("Finance") {
    NavigationStack {
        FinanceView()
    }
}
