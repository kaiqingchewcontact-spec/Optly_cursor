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
        Group {
            if appState.hasCompletedOnboarding {
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
            } else {
                OnboardingView {
                    appState.completeOnboarding()
                }
            }
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
                briefing: DailyBriefing.sample
            )
        }
    }
}

private struct SubscriptionsTabView: View {
    var body: some View {
        NavigationStack {
            SubscriptionsView()
        }
    }
}

private struct HabitsTabView: View {
    var body: some View {
        NavigationStack {
            HabitsView()
        }
    }
}

private struct FinanceTabView: View {
    var body: some View {
        NavigationStack {
            FinanceView()
        }
    }
}

private struct FocusTabView: View {
    var body: some View {
        NavigationStack {
            FocusView()
        }
    }
}

private struct SettingsTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            SettingsView()
        }
    }
}

#if DEBUG
#Preview("Optly Tabs") {
    RootTabView()
        .environmentObject(AppState(currentUser: .sample, isAuthenticated: true, isPremium: true, hasCompletedOnboarding: true))
}
#endif
