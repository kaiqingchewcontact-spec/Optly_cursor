import SwiftUI

enum StatTrend: Equatable {
    case up(String)
    case down(String)
    case neutral

    var symbol: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }

    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .Optly.orange
        case .neutral: return .secondary
        }
    }

    var caption: String? {
        switch self {
        case .up(let s), .down(let s): return s
        case .neutral: return nil
        }
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    var trend: StatTrend = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.Optly.indigo, .Optly.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(colors: [.Optly.indigo.opacity(0.12), .Optly.purple.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                Spacer()
                trendBadge
            }

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var trendBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.symbol)
                .font(.caption2.weight(.bold))
            if let caption = trend.caption {
                Text(caption)
                    .font(.caption2.weight(.medium))
            }
        }
        .foregroundStyle(trend.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trend.color.opacity(0.12), in: Capsule())
    }
}

#Preview("Stat grid") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        StatCard(icon: "dollarsign.circle.fill", value: "$342", label: "Savings this month", trend: .up("12%"))
        StatCard(icon: "flame.fill", value: "18", label: "Day streak", trend: .up("+3"))
        StatCard(icon: "brain.head.profile", value: "24h", label: "Focus hours", trend: .neutral)
        StatCard(icon: "heart.fill", value: "87", label: "Health score", trend: .down("2 pts"))
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
