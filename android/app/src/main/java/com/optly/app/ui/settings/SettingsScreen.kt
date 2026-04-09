package com.optly.app.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.optly.app.ui.theme.OptlyTheme

@Composable
fun SettingsScreen(modifier: Modifier = Modifier) {
    var health by remember { mutableStateOf(true) }
    var notifications by remember { mutableStateOf(true) }
    var dynamicColor by remember { mutableStateOf(true) }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        contentPadding = PaddingValues(bottom = 96.dp, top = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(text = "Settings", style = MaterialTheme.typography.headlineSmall)
        }
        item {
            SettingsToggleCard(
                title = "Health Connect",
                subtitle = "Sync steps, sleep, and heart rate for smarter energy insights.",
                checked = health,
                onCheckedChange = { health = it },
            )
        }
        item {
            SettingsToggleCard(
                title = "Daily nudges",
                subtitle = "Briefing reminders and streak protection.",
                checked = notifications,
                onCheckedChange = { notifications = it },
            )
        }
        item {
            SettingsToggleCard(
                title = "Dynamic color",
                subtitle = "Use Material You accents on Android 12+.",
                checked = dynamicColor,
                onCheckedChange = { dynamicColor = it },
            )
        }
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                ),
            ) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(text = "Account", style = MaterialTheme.typography.titleMedium)
                    Text(
                        text = "Manage subscription, export data, and connected banks in a future build.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsToggleCard(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = title, style = MaterialTheme.typography.titleMedium)
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Switch(checked = checked, onCheckedChange = onCheckedChange)
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun SettingsPreview() {
    OptlyTheme {
        SettingsScreen()
    }
}
