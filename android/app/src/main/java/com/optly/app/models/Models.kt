package com.optly.app.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.util.UUID

@Serializable
data class User(
    val id: String = UUID.randomUUID().toString(),
    val displayName: String,
    val email: String,
    val avatarUrl: String? = null,
    val energyLevel: Int,
    val xp: Int = 0,
    val level: Int = 1,
    val isPremium: Boolean = false,
    val trialEndsAtEpochMs: Long? = null,
) {
    companion object {
        val Mock = User(
            displayName = "Alex",
            email = "alex@optly.app",
            energyLevel = 78,
            xp = 1240,
            level = 7,
            isPremium = true,
        )
    }
}

@Serializable
data class DailyBriefing(
    val id: String = UUID.randomUUID().toString(),
    val dateEpochDay: Long,
    val headline: String,
    val summary: String,
    val topAction: String,
    val confidence: Float,
    val tags: List<String> = emptyList(),
) {
    companion object {
        val Mock = DailyBriefing(
            dateEpochDay = LocalDate.of(2026, 4, 9).toEpochDay(),
            headline = "High-focus morning, lighter afternoon",
            summary = "Block deep work before noon; shift admin and email to 2–4pm when energy dips.",
            topAction = "Schedule 90 minutes for your hardest task before 12:00.",
            confidence = 0.86f,
            tags = listOf("Energy", "Calendar", "Sleep"),
        )
    }
}

@Serializable
enum class SubscriptionCategory {
    @SerialName("streaming")
    STREAMING,

    @SerialName("productivity")
    PRODUCTIVITY,

    @SerialName("fitness")
    FITNESS,

    @SerialName("news")
    NEWS,

    @SerialName("other")
    OTHER,
}

@Serializable
data class Subscription(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val vendor: String,
    val monthlyPrice: Double,
    val renewalDateEpochDay: Long,
    val category: SubscriptionCategory,
    val usageScore: Float,
    val lastUsedEpochDay: Long?,
    val isEssential: Boolean = false,
) {
    val isLowUsage: Boolean get() = usageScore < 0.35f

    companion object {
        val MockList = listOf(
            Subscription(
                name = "Optly Premium",
                vendor = "Optly",
                monthlyPrice = 4.99,
                renewalDateEpochDay = 19_000L,
                category = SubscriptionCategory.PRODUCTIVITY,
                usageScore = 0.92f,
                lastUsedEpochDay = 19_010L,
                isEssential = true,
            ),
            Subscription(
                name = "StreamMax",
                vendor = "StreamMax Inc",
                monthlyPrice = 15.99,
                renewalDateEpochDay = 18_995L,
                category = SubscriptionCategory.STREAMING,
                usageScore = 0.18f,
                lastUsedEpochDay = 18_920L,
            ),
            Subscription(
                name = "FitPulse",
                vendor = "FitPulse",
                monthlyPrice = 9.99,
                renewalDateEpochDay = 19_005L,
                category = SubscriptionCategory.FITNESS,
                usageScore = 0.64f,
                lastUsedEpochDay = 18_998L,
            ),
            Subscription(
                name = "NewsWire+",
                vendor = "NewsWire",
                monthlyPrice = 6.50,
                renewalDateEpochDay = 19_012L,
                category = SubscriptionCategory.NEWS,
                usageScore = 0.41f,
                lastUsedEpochDay = 18_990L,
            ),
        )
    }
}

@Serializable
data class Habit(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val emoji: String,
    val targetPerWeek: Int,
    val completedThisWeek: Int,
    val streakDays: Int,
    val aiTip: String? = null,
) {
    val progress: Float
        get() = if (targetPerWeek <= 0) 0f else
            (completedThisWeek.toFloat() / targetPerWeek.toFloat()).coerceIn(0f, 1f)

    companion object {
        val MockList = listOf(
            Habit(
                title = "Morning movement",
                emoji = "🌅",
                targetPerWeek = 5,
                completedThisWeek = 3,
                streakDays = 12,
                aiTip = "Pair with your first coffee — same cue, higher follow-through.",
            ),
            Habit(
                title = "Read 20 min",
                emoji = "📚",
                targetPerWeek = 7,
                completedThisWeek = 5,
                streakDays = 4,
            ),
            Habit(
                title = "No phone in bed",
                emoji = "🌙",
                targetPerWeek = 7,
                completedThisWeek = 6,
                streakDays = 21,
                aiTip = "Charge across the room tonight to break the scroll loop.",
            ),
        )

        val MockSuggestions = listOf(
            "Stack \"walk\" right after lunch — your calendar shows a consistent gap.",
            "Try 2-minute \"start rituals\" before deep work to reduce friction.",
            "Your best streaks happen Mon/Wed; anchor new habits on those days.",
        )
    }
}

@Serializable
data class BudgetCategory(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val spent: Double,
    val budget: Double,
    val colorHex: String,
) {
    val ratio: Float
        get() = if (budget <= 0) 0f else (spent / budget).toFloat().coerceIn(0f, 1.5f)

    companion object {
        val MockList = listOf(
            BudgetCategory(name = "Housing", spent = 1800.0, budget = 1900.0, colorHex = "#5B5FEF"),
            BudgetCategory(name = "Food", spent = 420.0, budget = 500.0, colorHex = "#14B8A6"),
            BudgetCategory(name = "Transport", spent = 210.0, budget = 280.0, colorHex = "#F59E0B"),
            BudgetCategory(name = "Fun", spent = 190.0, budget = 200.0, colorHex = "#EC4899"),
        )
    }
}

@Serializable
data class MicroInvestment(
    val id: String = UUID.randomUUID().toString(),
    val label: String,
    val weeklyAmount: Double,
    val projectedYearGrowthPercent: Float,
    val riskLabel: String,
) {
    companion object {
        val MockList = listOf(
            MicroInvestment(
                label = "Round-ups",
                weeklyAmount = 12.50,
                projectedYearGrowthPercent = 6.2f,
                riskLabel = "Balanced",
            ),
            MicroInvestment(
                label = "ESG tilt",
                weeklyAmount = 25.0,
                projectedYearGrowthPercent = 7.1f,
                riskLabel = "Moderate",
            ),
        )
    }
}

@Serializable
data class FinanceSnapshot(
    val id: String = UUID.randomUUID().toString(),
    val monthLabel: String,
    val income: Double,
    val expenses: Double,
    val savingsRate: Float,
    val categories: List<BudgetCategory> = BudgetCategory.MockList,
    val savingsSuggestions: List<String> = listOf(
        "You spend 18% more on dining Fri–Sun — try a meal-prep block on Thursday.",
        "Subscriptions are 9% of spend; Optly can trim ~$47/mo with low-usage flags.",
    ),
    val microInvestments: List<MicroInvestment> = MicroInvestment.MockList,
) {
    companion object {
        val Mock = FinanceSnapshot(
            monthLabel = "April 2026",
            income = 7200.0,
            expenses = 5840.0,
            savingsRate = 0.19f,
        )
    }
}

@Serializable
enum class FocusMode {
    @SerialName("deep_work")
    DEEP_WORK,

    @SerialName("creative")
    CREATIVE,

    @SerialName("recovery")
    RECOVERY,

    @SerialName("social")
    SOCIAL,
}

@Serializable
data class FocusSession(
    val id: String = UUID.randomUUID().toString(),
    val mode: FocusMode,
    val startedAtEpochMs: Long,
    val durationMinutes: Int,
    val completed: Boolean,
    val blockedAppsCount: Int = 0,
) {
    companion object {
        val MockHistory = listOf(
            FocusSession(
                mode = FocusMode.DEEP_WORK,
                startedAtEpochMs = System.currentTimeMillis() - 86_400_000L,
                durationMinutes = 50,
                completed = true,
                blockedAppsCount = 6,
            ),
            FocusSession(
                mode = FocusMode.CREATIVE,
                startedAtEpochMs = System.currentTimeMillis() - 172_800_000L,
                durationMinutes = 90,
                completed = true,
                blockedAppsCount = 4,
            ),
            FocusSession(
                mode = FocusMode.RECOVERY,
                startedAtEpochMs = System.currentTimeMillis() - 259_200_000L,
                durationMinutes = 25,
                completed = false,
                blockedAppsCount = 8,
            ),
        )
    }
}

@Serializable
enum class InsightKind {
    @SerialName("health")
    HEALTH,

    @SerialName("finance")
    FINANCE,

    @SerialName("habits")
    HABITS,

    @SerialName("focus")
    FOCUS,

    @SerialName("subscriptions")
    SUBSCRIPTIONS,
}

@Serializable
data class InsightCard(
    val id: String = UUID.randomUUID().toString(),
    val kind: InsightKind,
    val title: String,
    val subtitle: String,
    val impactLabel: String?,
    val score: Float?,
) {
    companion object {
        val MockList = listOf(
            InsightCard(
                kind = InsightKind.HEALTH,
                title = "Sleep debt trending down",
                subtitle = "Average 7h 10m this week vs 6h 40m last week.",
                impactLabel = "+12% recovery",
                score = 0.82f,
            ),
            InsightCard(
                kind = InsightKind.SUBSCRIPTIONS,
                title = "$26.98/mo low-usage",
                subtitle = "StreamMax and NewsWire+ had sparse opens — cancel or pause?",
                impactLabel = "Save ~$324/yr",
                score = 0.74f,
            ),
            InsightCard(
                kind = InsightKind.FOCUS,
                title = "Peak focus: 9–11am",
                subtitle = "Protect this window; meetings after lunch line up with your dip.",
                impactLabel = "Deep work",
                score = 0.91f,
            ),
            InsightCard(
                kind = InsightKind.HABITS,
                title = "Streak risk on Sunday",
                subtitle = "Your \"morning movement\" often slips weekends — set a 10-min minimum.",
                impactLabel = "Habit guard",
                score = 0.66f,
            ),
        )
    }
}
