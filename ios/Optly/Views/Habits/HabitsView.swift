import SwiftUI

private struct HabitItem: Identifiable {
    let id = UUID()
    var title: String
    var progress: Double
    var streak: Int
    var category: String
    var symbol: String
}

private enum HabitCategory: String, CaseIterable, Identifiable {
    case health, finance, focus, mindfulness, fitness

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var symbol: String {
        switch self {
        case .health: return "heart.fill"
        case .finance: return "dollarsign.circle.fill"
        case .focus: return "brain.head.profile"
        case .mindfulness: return "leaf.fill"
        case .fitness: return "figure.run"
        }
    }
}

struct HabitsView: View {
    @State private var selectedHabit: HabitItem?
    @State private var showAddHabit = false
    @State private var flamePulse = false

    private let habits: [HabitItem] = [
        .init(title: "Morning sunlight", progress: 0.85, streak: 12, category: "Health", symbol: "sun.max.fill"),
        .init(title: "Read 20 pages", progress: 0.45, streak: 5, category: "Focus", symbol: "book.fill"),
        .init(title: "No spend day", progress: 0.6, streak: 3, category: "Finance", symbol: "banknote.fill"),
        .init(title: "Stretch", progress: 0.9, streak: 21, category: "Fitness", symbol: "figure.flexibility")
    ]

    private let aiSuggestions: [String] = [
        "Try a 10-minute walk after lunch—boosts afternoon energy by ~12% in similar profiles.",
        "Add a “shutdown ritual” habit to improve sleep consistency this week.",
        "Micro-habit: log one expense daily to sharpen finance awareness."
    ]

    private var totalStreak: Int { habits.map(\.streak).max() ?? 0 }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                gamificationHeader
                streakRow
                sectionHeader("Active habits")
                habitsGrid
                sectionHeader("AI suggestions")
                suggestionsSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddHabit = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.Optly.indigo, .primary)
                }
            }
        }
        .sheet(item: $selectedHabit) { habit in
            HabitDetailSheet(habit: habit)
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitSheet()
        }
        .onAppear {
            flamePulse = false
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                flamePulse = true
            }
        }
    }

    private var gamificationHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level 14")
                        .font(.title2.weight(.bold))
                    Text("2,450 XP to Level 15")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.Optly.purple.opacity(0.25), .Optly.indigo.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 52, height: 52)
                    Text("14")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.Optly.indigo)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(colors: [.Optly.indigo, .Optly.teal], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * 0.62)
                }
            }
            .frame(height: 10)
        }
        .padding(18)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var streakRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(
                    LinearGradient(colors: [.Optly.orange, .yellow], startPoint: .bottom, endPoint: .top)
                )
                .scaleEffect(flamePulse ? 1.08 : 0.94)
                .shadow(color: .Optly.orange.opacity(flamePulse ? 0.45 : 0.15), radius: flamePulse ? 12 : 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Best streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(totalStreak) days")
                    .font(.title3.weight(.bold))
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow.opacity(0.9))
                .font(.title2)
        }
        .padding(16)
        .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
    }

    private var habitsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(habits) { habit in
                Button {
                    selectedHabit = habit
                } label: {
                    VStack(spacing: 12) {
                        ProgressRing(
                            progress: habit.progress,
                            lineWidth: 10,
                            centerTitle: "\(Int(habit.progress * 100))%",
                            centerSubtitle: habit.title
                        )
                        .frame(height: 100)

                        HStack {
                            Image(systemName: habit.symbol)
                                .foregroundStyle(.Optly.teal)
                            Text(habit.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        Text("\(habit.streak)d streak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.Optly.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(aiSuggestions.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.Optly.purple)
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.Optly.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

// MARK: - Habit detail

private struct HabitDetailSheet: View {
    let habit: HabitItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        ProgressRing(progress: habit.progress, lineWidth: 14, centerTitle: "\(Int(habit.progress * 100))%", centerSubtitle: "This week")
                            .frame(width: 120, height: 120)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(habit.title)
                                .font(.title2.weight(.bold))
                            Text(habit.category)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Label("\(habit.streak) day streak", systemImage: "flame.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.Optly.orange)
                        }
                        Spacer(minLength: 0)
                    }

                    Text("History")
                        .font(.headline)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 160)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Chart placeholder — last 8 weeks")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add habit

private struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: HabitCategory = .health

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $title)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases) { c in
                            Label(c.title, systemImage: c.symbol).tag(c)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("New habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview("Habits") {
    NavigationStack {
        HabitsView()
    }
}
