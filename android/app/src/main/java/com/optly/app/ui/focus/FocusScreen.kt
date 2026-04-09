package com.optly.app.ui.focus

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.optly.app.models.FocusMode
import com.optly.app.models.FocusSession
import com.optly.app.models.User
import com.optly.app.ui.components.ProgressRing
import com.optly.app.ui.theme.OptlyTheme
import kotlinx.coroutines.delay

@Composable
fun FocusScreen(modifier: Modifier = Modifier) {
    val user = remember { User.Mock }
    var selectedMode by remember { mutableStateOf(FocusMode.DEEP_WORK) }
    val totalMinutes = 50
    var remainingSeconds by remember { mutableIntStateOf(totalMinutes * 60) }
    LaunchedEffect(Unit) {
        while (remainingSeconds > 0) {
            delay(1_000)
            remainingSeconds--
        }
    }
    val progress = 1f - (remainingSeconds / (totalMinutes * 60f).coerceAtLeast(1f))

    val transition = rememberInfiniteTransition(label = "pulse")
    val pulse by transition.animateFloat(
        initialValue = 0.92f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseAnim",
    )

    val blockedApps = remember {
        listOf("Instagram", "TikTok", "YouTube", "News", "Slack", "Messages")
    }
    val history = remember { FocusSession.MockHistory }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        contentPadding = PaddingValues(bottom = 96.dp, top = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Text(text = "Focus modes", style = MaterialTheme.typography.headlineSmall)
        }
        item {
            Text(
                text = "Energy today: ${user.energyLevel}% — ${modeHint(selectedMode)}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                FocusMode.entries.forEach { mode ->
                    FilterChip(
                        selected = selectedMode == mode,
                        onClick = { selectedMode = mode },
                        label = { Text(modeLabel(mode)) },
                    )
                }
            }
        }
        item {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                ProgressRing(
                    progress = progress * pulse,
                    size = 200.dp,
                    strokeWidth = 14.dp,
                    centerContent = {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = formatTime(remainingSeconds),
                                style = MaterialTheme.typography.displaySmall,
                            )
                            Text(
                                text = modeLabel(selectedMode),
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.tertiary,
                            )
                        }
                    },
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Demo timer — wire to WorkManager / foreground service for real sessions",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        item {
            Text(text = "Blocked apps (example)", style = MaterialTheme.typography.titleMedium)
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                blockedApps.take(4).forEach { app ->
                    AssistChip(onClick = {}, label = { Text(app) })
                }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                blockedApps.drop(4).forEach { app ->
                    AssistChip(onClick = {}, label = { Text(app) })
                }
            }
        }
        item {
            Text(text = "Recent sessions", style = MaterialTheme.typography.titleMedium)
        }
        items(history, key = { it.id }) { session ->
            SessionCard(session)
        }
    }
}

private fun modeLabel(mode: FocusMode): String = when (mode) {
    FocusMode.DEEP_WORK -> "Deep work"
    FocusMode.CREATIVE -> "Creative"
    FocusMode.RECOVERY -> "Recovery"
    FocusMode.SOCIAL -> "Social"
}

private fun modeHint(mode: FocusMode): String = when (mode) {
    FocusMode.DEEP_WORK -> "Protect a single priority task."
    FocusMode.CREATIVE -> "Loosen structure, keep distractions off."
    FocusMode.RECOVERY -> "Short bursts; no guilt if you pause."
    FocusMode.SOCIAL -> "Batch messages; avoid context switching."
}

private fun formatTime(totalSeconds: Int): String {
    val m = totalSeconds / 60
    val s = totalSeconds % 60
    return "%02d:%02d".format(m, s)
}

@Composable
private fun SessionCard(session: FocusSession) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(text = modeLabel(session.mode), style = MaterialTheme.typography.titleSmall)
            Text(
                text = "${session.durationMinutes} min · ${if (session.completed) "Completed" else "Paused"} · ${session.blockedAppsCount} apps blocked",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun FocusPreview() {
    OptlyTheme {
        FocusScreen()
    }
}
