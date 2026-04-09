package com.optly.app.ui.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.optly.app.ai.InsightGenerator
import com.optly.app.models.DailyBriefing
import com.optly.app.models.InsightCard
import com.optly.app.models.Subscription
import com.optly.app.models.User
import com.optly.app.services.HealthConnectService
import com.optly.app.services.SyncService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class QuickStat(
    val title: String,
    val value: String,
    val subtitle: String? = null,
)

data class DashboardUiState(
    val user: User = User.Mock,
    val briefing: DailyBriefing = DailyBriefing.Mock,
    val insights: List<InsightCard> = InsightCard.MockList,
    val quickStats: List<QuickStat> = emptyList(),
    val isRefreshing: Boolean = false,
    val healthStepsToday: Long? = null,
    val healthNote: String? = null,
)

@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val insightGenerator: InsightGenerator,
    private val healthConnect: HealthConnectService,
    private val syncService: SyncService,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    init {
        rebuildQuickStats()
    }

    fun refresh() {
        viewModelScope.launch {
            _uiState.update { it.copy(isRefreshing = true) }
            val steps = healthConnect.readTodaySteps()
            val user = _uiState.value.user.copy(energyLevel = _uiState.value.user.energyLevel)
            val lines = buildList {
                steps?.let { add("Steps today (Health Connect): $it") }
                add("Subscriptions flagged: 2 low-usage")
                add("Next calendar crunch: 2–4pm")
            }
            val briefing = insightGenerator.generateBriefing(user, lines)
            val insights = insightGenerator.refreshInsights(user, InsightCard.MockList)
            syncService.cacheBriefing(briefing)
            syncService.pushUserSnapshot(user)
            _uiState.update {
                it.copy(
                    briefing = briefing,
                    insights = insights,
                    healthStepsToday = steps,
                    healthNote = when {
                        steps == null -> "Connect Health Connect for live steps"
                        else -> null
                    },
                    isRefreshing = false,
                )
            }
            rebuildQuickStats()
        }
    }

    private fun rebuildQuickStats() {
        val s = _uiState.value
        val monthlySubs = Subscription.MockList.sumOf { it.monthlyPrice }
        val savings = Subscription.MockList
            .filter { it.isLowUsage }
            .sumOf { it.monthlyPrice }
        _uiState.update {
            it.copy(
                quickStats = listOf(
                    QuickStat("Energy", "${s.user.energyLevel}%", "Self-reported"),
                    QuickStat("Subs", "$${"%.0f".format(monthlySubs)}/mo", "Tracked"),
                    QuickStat("Save", "$${"%.0f".format(savings)}/mo", "Low-usage est."),
                    QuickStat(
                        "Steps",
                        s.healthStepsToday?.toString() ?: "—",
                        s.healthNote ?: "Today",
                    ),
                ),
            )
        }
    }
}
