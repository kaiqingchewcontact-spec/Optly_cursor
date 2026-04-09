package com.optly.app.ai

import com.optly.app.models.DailyBriefing
import com.optly.app.models.InsightCard
import com.optly.app.models.InsightKind
import com.optly.app.models.User
import java.time.LocalDate
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.roundToInt

@Singleton
class InsightGenerator @Inject constructor(
    private val onDevice: OnDeviceAIEngine,
    private val cloud: CloudAIService,
) {

    suspend fun generateBriefing(user: User, contextLines: List<String>): DailyBriefing {
        val signals = floatArrayOf(
            user.energyLevel / 100f,
            0.62f,
            0.28f,
            if (user.isPremium) 1f else 0.4f,
            (user.xp % 500) / 500f,
            user.level / 20f,
            0.55f,
            0.71f,
        )
        val score = onDevice.energyScoreFromSignals(signals)
        val prompt = buildString {
            appendLine("You are Optly, a concise life optimizer. Produce a short daily briefing.")
            appendLine("User: ${user.displayName}, energy self-report: ${user.energyLevel}%, premium=${user.isPremium}.")
            appendLine("On-device energy score: ${(score * 100).roundToInt()}%.")
            contextLines.forEach { appendLine(it) }
            appendLine("Return: headline (max 8 words), summary (2 sentences), topAction (1 imperative sentence).")
        }
        val cloudText = cloud.completeBriefing(prompt).getOrDefault(prompt)
        return parseBriefingFromCloudText(cloudText, score)
    }

    fun refreshInsights(user: User, baseline: List<InsightCard>): List<InsightCard> {
        val embedding = onDevice.embeddingForText(user.displayName + user.email)
        val jitter = embedding.firstOrNull() ?: 0.5f
        val adjusted = baseline.mapIndexed { index, card ->
            val bump = (jitter * 0.04f * (index + 1)) % 0.08f
            card.copy(score = (card.score?.plus(bump))?.coerceIn(0f, 1f))
        }
        return adjusted
    }

    private fun parseBriefingFromCloudText(text: String, confidence: Float): DailyBriefing {
        val lines = text.lines().map { it.trim() }.filter { it.isNotEmpty() }
        val headline = lines.firstOrNull() ?: "Today, protect your peak focus window"
        val summary = lines.drop(1).take(2).joinToString(" ").ifBlank {
            "Balance deep work with recovery; small wins compound when timed to your energy curve."
        }
        val topAction = lines.lastOrNull { it.contains(" ", ignoreCase = true) && it.length < 120 }
            ?: "Book a 25-minute focus block on your hardest task before noon."
        return DailyBriefing(
            id = UUID.randomUUID().toString(),
            dateEpochDay = LocalDate.now().toEpochDay(),
            headline = headline.removePrefix("Headline:").trim(),
            summary = summary,
            topAction = topAction.removePrefix("Action:").trim(),
            confidence = confidence.coerceIn(0.55f, 0.95f),
            tags = listOf("AI", "Energy", "Plan"),
        )
    }

    fun insightFromSubscriptionSpend(monthlyTotal: Double, savingsOpportunity: Double): InsightCard {
        return InsightCard(
            kind = InsightKind.SUBSCRIPTIONS,
            title = "$${"%.0f".format(monthlyTotal)}/mo active subs",
            subtitle = "Optly estimates $${"%.0f".format(savingsOpportunity)}/mo recoverable from low-usage services.",
            impactLabel = "Guardian",
            score = 0.72f,
        )
    }
}
