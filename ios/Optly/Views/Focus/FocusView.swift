import SwiftUI

private enum FocusMode: String, CaseIterable, Identifiable {
    case deepWork = "Deep Work"
    case creative = "Creative"
    case meetingPrep = "Meeting Prep"
    case windDown = "Wind Down"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .deepWork: return "scope"
        case .creative: return "paintpalette.fill"
        case .meetingPrep: return "person.2.fill"
        case .windDown: return "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .deepWork: return .Optly.indigo
        case .creative: return .Optly.purple
        case .meetingPrep: return .Optly.teal
        case .windDown: return .Optly.orange
        }
    }
}

private struct BlockedApp: Identifiable {
    let id = UUID()
    var name: String
    var symbol: String
}

private struct BreakSlot: Identifiable {
    let id = UUID()
    var time: String
    var label: String
}

private struct FocusSession: Identifiable {
    let id = UUID()
    var title: String
    var durationMinutes: Int
    var when: String
}

struct FocusView: View {
    @State private var selectedMode: FocusMode = .deepWork
    @State private var timerProgress: Double = 0.42
    @State private var remainingSeconds: Int = 25 * 60 + 18

    private let energyScore: Double = 0.78
    private let energyLabel = "Balanced peak"

    private let blocked: [BlockedApp] = [
        .init(name: "Social", symbol: "bubble.left.and.bubble.right.fill"),
        .init(name: "Video", symbol: "play.rectangle.fill"),
        .init(name: "News", symbol: "newspaper.fill")
    ]

    private let breaks: [BreakSlot] = [
        .init(time: "10:30", label: "Micro-break"),
        .init(time: "12:15", label: "Lunch reset"),
        .init(time: "15:00", label: "Walk + water"),
        .init(time: "18:30", label: "Wind down")
    ]

    private let history: [FocusSession] = [
        .init(title: "Deep Work", durationMinutes: 52, when: "Yesterday, 9:12am"),
        .init(title: "Creative", durationMinutes: 38, when: "Mon, 2:40pm"),
        .init(title: "Meeting Prep", durationMinutes: 22, when: "Mon, 8:05am")
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                energyCard
                modeSelector
                timerCard
                sectionTitle("Blocked apps")
                blockedAppsSection
                sectionTitle("Break schedule")
                breakTimeline
                sectionTitle("Session history")
                historySection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.large)
    }

    private var energyCard: some View {
        HStack(spacing: 16) {
            ZStack {
                ProgressRing(
                    progress: energyScore,
                    lineWidth: 10,
                    gradient: LinearGradient(colors: [.Optly.teal, .Optly.indigo], startPoint: .bottomLeading, endPoint: .topTrailing),
                    centerTitle: "\(Int(energyScore * 100))",
                    centerSubtitle: "Energy"
                )
                .frame(width: 88, height: 88)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Current energy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(energyLabel)
                    .font(.title3.weight(.bold))
                Text("Pulled from Health trends, sleep, and HRV-style signals (mock).")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus mode")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FocusMode.allCases) { mode in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                selectedMode = mode
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: mode.symbol)
                                    .font(.title2)
                                Text(mode.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(selectedMode == mode ? Color.white : Color.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(width: 118)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        selectedMode == mode
                                            ? LinearGradient(colors: [mode.tint, mode.tint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [Color.Optly.elevated, Color.Optly.elevated], startPoint: .top, endPoint: .bottom)
                                    )
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(selectedMode == mode ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var timerCard: some View {
        VStack(spacing: 20) {
            Text("Session timer")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                ProgressRing(
                    progress: timerProgress,
                    lineWidth: 14,
                    gradient: LinearGradient(colors: [selectedMode.tint, .Optly.purple], startPoint: .leading, endPoint: .trailing),
                    centerTitle: formattedTime,
                    centerSubtitle: selectedMode.rawValue
                )
                .frame(width: 200, height: 200)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        timerProgress = min(1, timerProgress + 0.08)
                        remainingSeconds = max(0, remainingSeconds - 120)
                    }
                } label: {
                    Label("Skip ahead (demo)", systemImage: "forward.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.Optly.indigo)

                Button {
                    timerProgress = 0
                    remainingSeconds = 25 * 60
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
    }

    private var blockedAppsSection: some View {
        VStack(spacing: 10) {
            ForEach(blocked) { app in
                HStack(spacing: 12) {
                    Image(systemName: app.symbol)
                        .foregroundStyle(.Optly.orange)
                        .frame(width: 32)
                    Text(app.name)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var breakTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(breaks.enumerated()), id: \.element.id) { index, slot in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(LinearGradient(colors: [.Optly.teal, .Optly.indigo], startPoint: .top, endPoint: .bottom))
                            .frame(width: 12, height: 12)
                        if index < breaks.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.12))
                                .frame(width: 2, height: 28)
                        }
                    }
                    .frame(width: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.time)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.Optly.teal)
                        Text(slot.label)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.bottom, index < breaks.count - 1 ? 10 : 0)
                }
            }
        }
        .padding(16)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var historySection: some View {
        VStack(spacing: 10) {
            ForEach(history) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(.subheadline.weight(.semibold))
                        Text(session.when)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(session.durationMinutes)m")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.Optly.purple)
                }
                .padding(14)
                .background(Color.Optly.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

#Preview("Focus") {
    NavigationStack {
        FocusView()
    }
}
