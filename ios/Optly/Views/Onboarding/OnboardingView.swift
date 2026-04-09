import SwiftUI

private struct OnboardingPage: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var symbols: [String]
    var accent: Color
}

struct OnboardingView: View {
    /// When provided (e.g. from a full-screen cover), called after the user starts the trial.
    var onFinish: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        .init(
            title: "Your AI life optimizer",
            subtitle: "Optly connects health, money, and focus so you get one calm briefing—and clear next steps—every day.",
            symbols: ["sparkles", "wand.and.stars", "brain.head.profile"],
            accent: .Optly.indigo
        ),
        .init(
            title: "Understand your energy",
            subtitle: "Link Apple Health to personalize focus blocks, recovery, and habit suggestions to how you actually feel.",
            symbols: ["heart.text.square.fill", "bed.double.fill", "figure.run"],
            accent: .Optly.teal
        ),
        .init(
            title: "Finance, optional but powerful",
            subtitle: "Connect accounts with Plaid to surface subscriptions, savings, and cash flow—only if you want it.",
            symbols: ["building.columns.fill", "creditcard.fill", "chart.pie.fill"],
            accent: .Optly.purple
        ),
        .init(
            title: "Set your first goals",
            subtitle: "Pick two priorities. Start your free trial and let Optly keep you on track with gentle, intelligent nudges.",
            symbols: ["flag.checkered", "target", "flame.fill"],
            accent: .Optly.orange
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color.Optly.indigo.opacity(0.06),
                    Color.Optly.teal.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                        onboardingPageView(p)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                pageIndicators

                VStack(spacing: 12) {
                    if page < pages.count - 1 {
                        Button {
                            withAnimation { page += 1 }
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.Optly.indigo)

                        Button("Skip for now") {
                            withAnimation { page = pages.count - 1 }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    } else {
                        Button {
                            if let onFinish {
                                onFinish()
                            } else {
                                dismiss()
                            }
                        } label: {
                            Text("Start free trial")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [.Optly.indigo, .Optly.purple], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .shadow(color: .Optly.indigo.opacity(0.35), radius: 12, y: 6)

                        Text("No charge until day 8 · Cancel anytime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 8)
            }
        }
    }

    private func onboardingPageView(_ p: OnboardingPage) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)

            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [p.accent.opacity(0.25), .Optly.purple.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 240)
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    }

                HStack(spacing: 20) {
                    ForEach(p.symbols, id: \.self) { name in
                        Image(systemName: name)
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(colors: [p.accent, .Optly.teal], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: p.accent.opacity(0.25), radius: 8, y: 4)
                    }
                }
                .symbolEffect(.bounce, value: page)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Text(p.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(p.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Group {
                    if i == page {
                        Capsule()
                            .fill(LinearGradient(colors: [.Optly.indigo, .Optly.purple], startPoint: .leading, endPoint: .trailing))
                    } else {
                        Capsule()
                            .fill(Color.primary.opacity(0.15))
                    }
                }
                .frame(width: i == page ? 24 : 8, height: 8)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
            }
        }
        .padding(.bottom, 8)
    }
}

#Preview("Onboarding") {
    OnboardingView()
}
