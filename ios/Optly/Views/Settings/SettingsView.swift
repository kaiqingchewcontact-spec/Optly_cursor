import SwiftUI

private struct ConnectedAccount: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var symbol: String
    var connected: Bool
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var notifyDailyBrief = true
    @State private var notifyFocus = true
    @State private var notifyFinance = false
    @State private var analyticsOptIn = true
    @State private var showOnboarding = false

    private let accounts: [ConnectedAccount] = [
        .init(title: "Apple Health", subtitle: "Energy, sleep, activity", symbol: "heart.text.square.fill", connected: true),
        .init(title: "Calendar", subtitle: "Focus windows & meetings", symbol: "calendar", connected: true),
        .init(title: "Finance", subtitle: "Plaid-linked accounts", symbol: "building.columns.fill", connected: false)
    ]

    private var profileInitials: String {
        guard let name = appState.currentUser?.name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        let s = (first + last).uppercased()
        return s.isEmpty ? String(name.prefix(1)).uppercased() : s
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.Optly.indigo, .Optly.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 64, height: 64)
                        Text(profileInitials)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let user = appState.currentUser {
                            Text(user.name)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Guest")
                                .font(.headline)
                            Text("Sign in to sync across devices")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Edit") { }
                        .buttonStyle(.bordered)
                }
                .listRowBackground(Color.clear)
            }

            Section("Optly subscription") {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.isPremium ? "Pro" : "Free trial")
                            .font(.subheadline.weight(.semibold))
                        Text(
                            appState.isPremium
                                ? "You have full access to AI actions, finance sync, and focus modes."
                                : "7 days left — unlock AI actions & Plaid sync"
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if !appState.isPremium {
                    Button {
                        appState.setPremium(true)
                    } label: {
                        Label("Upgrade to Pro", systemImage: "sparkles")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(
                        LinearGradient(colors: [.Optly.indigo, .Optly.purple], startPoint: .leading, endPoint: .trailing)
                    )
                }
            }

            Section("Connected accounts") {
                ForEach(accounts) { acct in
                    HStack(spacing: 12) {
                        Image(systemName: acct.symbol)
                            .font(.title2)
                            .foregroundStyle(acct.connected ? Color.Optly.teal : Color.secondary)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(acct.title)
                                .font(.subheadline.weight(.semibold))
                            Text(acct.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(acct.connected ? "Connected" : "Connect")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(acct.connected ? Color.Optly.teal : Color.Optly.indigo)
                    }
                }
            }

            Section("Notifications") {
                Toggle("Daily briefing", isOn: $notifyDailyBrief)
                Toggle("Focus session nudges", isOn: $notifyFocus)
                Toggle("Finance alerts", isOn: $notifyFinance)
            }

            Section("Privacy & data") {
                Toggle("Help improve Optly (anonymous)", isOn: $analyticsOptIn)
                NavigationLink("Data retention") { Text("Placeholder") }
                NavigationLink("Manage permissions") { Text("Placeholder") }
            }

            Section {
                Button {
                    // Export
                } label: {
                    Label("Export my data", systemImage: "square.and.arrow.up.on.square")
                }
            }

            Section("About") {
                NavigationLink("Support & feedback") { Text("Placeholder") }
                NavigationLink("Terms & privacy") { Text("Placeholder") }
                Button("Replay onboarding") {
                    showOnboarding = true
                }
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0 (1)")
                        .foregroundStyle(.secondary)
                }
            }

            #if DEBUG
            Section("Debug") {
                Toggle("Premium", isOn: Binding(
                    get: { appState.isPremium },
                    set: { appState.setPremium($0) }
                ))
                Toggle("Onboarding complete", isOn: Binding(
                    get: { appState.hasCompletedOnboarding },
                    set: { appState.setOnboardingComplete($0) }
                ))
            }
            #endif
        }
        .navigationTitle("Settings")
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onFinish: {
                showOnboarding = false
                appState.completeOnboarding()
            })
        }
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState(currentUser: .sample, isAuthenticated: true, isPremium: false, hasCompletedOnboarding: true))
    }
}
