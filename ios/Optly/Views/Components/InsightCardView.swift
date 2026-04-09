import SwiftUI

// MARK: - Design tokens (shared across Optly views)

extension Color {
    enum Optly {
        static let indigo = Color(red: 0.39, green: 0.35, blue: 0.98)
        static let purple = Color(red: 0.55, green: 0.36, blue: 0.96)
        static let teal = Color(red: 0.14, green: 0.72, blue: 0.68)
        static let orange = Color(red: 1.0, green: 0.52, blue: 0.24)
        static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
        static let elevated = Color(uiColor: .tertiarySystemGroupedBackground)
    }
}

// MARK: - Model

enum InsightCategory: String, CaseIterable, Identifiable {
    case finance, health, productivity, habits, focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .finance: return "Finance"
        case .health: return "Health"
        case .productivity: return "Productivity"
        case .habits: return "Habits"
        case .focus: return "Focus"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .finance:
            return LinearGradient(colors: [.Optly.teal.opacity(0.35), .Optly.indigo.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .health:
            return LinearGradient(colors: [.Optly.teal.opacity(0.4), .green.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .productivity:
            return LinearGradient(colors: [.Optly.indigo.opacity(0.35), .Optly.purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .habits:
            return LinearGradient(colors: [.Optly.orange.opacity(0.3), .Optly.purple.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .focus:
            return LinearGradient(colors: [.Optly.purple.opacity(0.35), .Optly.teal.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Visual tone for the insight card chrome (derived from `InsightCard.Priority` + type).
private enum InsightPresentationTone: String {
    case tip, warning, opportunity, milestone

    var symbolName: String {
        switch self {
        case .tip: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .opportunity: return "sparkles"
        case .milestone: return "flag.checkered"
        }
    }

    var tint: Color {
        switch self {
        case .tip: return .Optly.teal
        case .warning: return .Optly.orange
        case .opportunity: return .Optly.purple
        case .milestone: return .Optly.indigo
        }
    }
}

private extension InsightCard {
    var presentationCategory: InsightCategory {
        switch type {
        case .savings: return .finance
        case .health: return .health
        case .productivity: return .productivity
        case .habit: return .habits
        }
    }

    var presentationTone: InsightPresentationTone {
        switch priority {
        case .urgent: return .warning
        case .high: return .opportunity
        case .medium: return .tip
        case .low: return .tip
        }
    }

    var displayImpactLabel: String {
        "Impact \(impactScore)"
    }
}

// MARK: - View

struct InsightCardView: View {
    let card: InsightCard
    var onAction: () -> Void = {}

    var body: some View {
        let tone = card.presentationTone
        let category = card.presentationCategory
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tone.symbolName)
                    .font(.title2)
                    .foregroundStyle(tone.tint)
                    .frame(width: 40, height: 40)
                    .background(tone.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(card.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack {
                Text(card.displayImpactLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                Spacer()

                Button(action: onAction) {
                    Text(card.actionButtonText)
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.Optly.indigo)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.Optly.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(category.gradient)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

#Preview("Insight cards") {
    ScrollView {
        LazyVStack(spacing: 16) {
            InsightCardView(card: .sample)
            InsightCardView(card: InsightCard.samples[1])
            InsightCardView(card: InsightCard(
                id: UUID(),
                type: .productivity,
                title: "Deep work block",
                description: "Calendar shows a 2-hour gap—ideal for creative work while energy is peaking.",
                impactScore: 88,
                actionButtonText: "Start focus",
                associatedData: [:],
                priority: .high
            ))
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
