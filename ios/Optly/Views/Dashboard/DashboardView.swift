import SwiftUI

private struct EnergyLevel: Equatable {
    var label: String
    var score: Double // 0...1

    var tint: Color {
        if score >= 0.75 { return .Optly.teal }
        if score >= 0.45 { return .Optly.orange }
        return .red.opacity(0.85)
    }
}

struct DashboardView: View {
    var userName: String = "Alex"
    var energy: EnergyLevel = .init(label: "High", score: 0.82)
    var briefingSummary: String = "Today favors deep work before noon, a lighter afternoon, and an early wind-down. Finance insights flagged one subscription worth revisiting."

    @State private var briefingExpanded = false

    private let insights: [InsightCard] = [
        InsightCard(
            id: UUID(),
            type: .savings,
            title: "Subscription overlap",
            description: "You have two music services with low overlap usage—consolidating could save about $14/month.",
            impactScore: 82,
            actionButtonText: "Review",
            associatedData: ["estimatedMonthlySavings": "14"],
            priority: .high
        ),
        InsightCard(
            id: UUID(),
            type: .health,
            title: "Hydration nudge",
            description: "You’re below your usual intake by mid-day—two glasses before 3pm lifts afternoon focus.",
            impactScore: 45,
            actionButtonText: "Log water",
            associatedData: [:],
            priority: .medium
        ),
        InsightCard(
            id: UUID(),
            type: .productivity,
            title: "Meeting buffer",
            description: "Back-to-back calls at 2pm—add a 10-minute buffer to protect recovery.",
            impactScore: 58,
            actionButtonText: "Adjust calendar",
            associatedData: [:],
            priority: .urgent
        )
    ]

    private let priorities: [String] = [
        "Complete the 90-minute deep work block before 12:30",
        "Review subscription list and pause one low-usage service",
        "Walk 15 minutes after lunch for energy stability"
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header
                briefingCard
                statsRow
                sectionTitle("Insights for you")
                insightsSection
                sectionTitle("Today’s priorities")
                prioritiesSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(userName)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                energyPill
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.Optly.indigo, .Optly.purple, .Optly.teal.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .Optly.indigo.opacity(0.35), radius: 24, y: 12)
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default: return "Hello,"
        }
    }

    private var energyPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .white.opacity(0.9))
            VStack(alignment: .leading, spacing: 2) {
                Text("Energy")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                Text(energy.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Gauge(value: energy.score) { }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(energy.tint)
                .frame(width: 56)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var briefingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Daily briefing", systemImage: "sparkles.rectangle.stack")
                    .font(.headline)
                Spacer()
                Image(systemName: briefingExpanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    briefingExpanded.toggle()
                }
            }

            Text(briefingSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(briefingExpanded ? nil : 2)

            if briefingExpanded {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.Optly.purple)
                    Text("Generated from your health, calendar, and finance signals.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.Optly.indigo.opacity(0.25), .Optly.teal.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(icon: "dollarsign.circle.fill", value: "$342", label: "Savings this month", trend: .up("12%"))
            StatCard(icon: "flame.fill", value: "18", label: "Day streak", trend: .up("+3"))
            StatCard(icon: "brain.head.profile", value: "24h", label: "Focus hours", trend: .neutral)
            StatCard(icon: "heart.fill", value: "87", label: "Health score", trend: .down("2 pts"))
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.top, 4)
    }

    private var insightsSection: some View {
        LazyVStack(spacing: 14) {
            ForEach(insights) { card in
                InsightCardView(card: card) { }
            }
        }
    }

    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(priorities.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            LinearGradient(colors: [.Optly.indigo, .Optly.purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle()
                        )
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

#Preview("Dashboard") {
    NavigationStack {
        DashboardView()
    }
}
