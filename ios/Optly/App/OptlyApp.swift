import SwiftUI
import UIKit

@main
struct OptlyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App delegate (push, shortcuts, lifecycle hooks)

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureAppearance()
        return true
    }

    private func configureAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}

// MARK: - Tab shell

private struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            DashboardTabView()
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }

            SubscriptionsTabView()
                .tabItem { Label("Subscriptions", systemImage: "creditcard") }

            HabitsTabView()
                .tabItem { Label("Habits", systemImage: "checkmark.circle") }

            FinanceTabView()
                .tabItem { Label("Finance", systemImage: "dollarsign.circle") }

            FocusTabView()
                .tabItem { Label("Focus", systemImage: "scope") }

            SettingsTabView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

// MARK: - Placeholder screens (replace with feature modules)

private struct DashboardTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            DashboardView(
                userName: appState.currentUser?.name ?? "there",
                briefingSummary: DailyBriefing.sample.greeting
            )
        }
    }
}

private struct SubscriptionsTabView: View {
    var body: some View {
        NavigationStack {
            List(Subscription.samples) { sub in
                VStack(alignment: .leading, spacing: 4) {
                    Text(sub.name).font(.headline)
                    Text(sub.provider).font(.caption).foregroundStyle(.secondary)
                    Text("AI: \(sub.aiRecommendation.rawValue.capitalized)")
                        .font(.caption2)
                }
            }
            .navigationTitle("Subscriptions")
        }
    }
}

private struct HabitsTabView: View {
    var body: some View {
        NavigationStack {
            List(Habit.samples) { habit in
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name).font(.headline)
                    Text("\(habit.streak) day streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Habits")
        }
    }
}

private struct FinanceTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("This month") {
                    Text(FinanceSnapshot.monthFormatter.string(from: FinanceSnapshot.sample.monthStart))
                    Text("Savings rate: \(Int(FinanceSnapshot.sample.savingsRate * 100))%")
                }
                Section("Suggestions") {
                    ForEach(FinanceSnapshot.sample.aiSavingsSuggestions, id: \.self) { line in
                        Text(line)
                    }
                }
            }
            .navigationTitle("Finance")
        }
    }
}

private struct FocusTabView: View {
    var body: some View {
        NavigationStack {
            List(FocusSession.samples) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.mode.rawValue.camelCaseToWords)
                        .font(.headline)
                    if let end = session.endTime {
                        Text(FocusSession.intervalFormatter.string(from: session.startTime, to: end) ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Score: \(session.productivityScore)")
                        .font(.caption2)
                }
            }
            .navigationTitle("Focus")
        }
    }
}

private struct SettingsTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let user = appState.currentUser {
                        LabeledContent("Name", value: user.name)
                        LabeledContent("Email", value: user.email)
                    } else {
                        Text("Not signed in")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Optly") {
                    Toggle("Premium", isOn: Binding(
                        get: { appState.isPremium },
                        set: { appState.setPremium($0) }
                    ))
                    Toggle("Onboarding complete", isOn: Binding(
                        get: { appState.hasCompletedOnboarding },
                        set: { appState.setOnboardingComplete($0) }
                    ))
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Small helpers

private extension String {
    var camelCaseToWords: String {
        unicodeScalars.reduce("") { result, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar) && !result.isEmpty {
                return result + " " + String(scalar).lowercased()
            }
            return result + String(scalar)
        }
    }
}

#if DEBUG
#Preview("Optly Tabs") {
    RootTabView()
        .environmentObject(AppState(currentUser: .sample, isAuthenticated: true, isPremium: true, hasCompletedOnboarding: true))
}
#endif
