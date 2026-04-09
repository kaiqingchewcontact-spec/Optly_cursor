package com.optly.app.ui.subscriptions

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Radar
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.optly.app.models.Subscription
import com.optly.app.models.SubscriptionCategory
import com.optly.app.ui.theme.OptlyOrange
import com.optly.app.ui.theme.OptlyTheme

@Composable
fun SubscriptionsScreen(modifier: Modifier = Modifier) {
    val subs = remember { Subscription.MockList }
    var filter by remember { mutableStateOf<SubscriptionCategory?>(null) }
    val filtered = remember(filter, subs) {
        subs.filter { filter == null || it.category == filter }
    }
    val total = filtered.sumOf { it.monthlyPrice }
    val savings = subs.filter { it.isLowUsage }.sumOf { it.monthlyPrice }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        contentPadding = PaddingValues(bottom = 96.dp, top = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Text(
                text = "Subscription guardian",
                style = MaterialTheme.typography.headlineSmall,
            )
        }
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SummaryTile(
                    title = "Monthly spend",
                    value = "$${"%.2f".format(total)}",
                    modifier = Modifier.weight(1f),
                )
                SummaryTile(
                    title = "Savings signal",
                    value = "$${"%.2f".format(savings)}/mo",
                    highlight = true,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        item {
            Text(
                text = "Low-usage subscriptions are highlighted — pause or cancel to reclaim cash flow.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        item {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                FilterChip(
                    selected = filter == null,
                    onClick = { filter = null },
                    label = { Text("All") },
                )
                SubscriptionCategory.entries.forEach { cat ->
                    FilterChip(
                        selected = filter == cat,
                        onClick = { filter = if (filter == cat) null else cat },
                        label = { Text(cat.name.lowercase().replaceFirstChar { it.uppercase() }) },
                    )
                }
            }
        }
        item {
            Button(
                onClick = { /* Plaid / account linking */ },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Filled.Radar, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Scan linked accounts")
            }
        }
        items(filtered, key = { it.id }) { sub ->
            SubscriptionRow(sub)
        }
    }
}

@Composable
private fun SummaryTile(
    title: String,
    value: String,
    modifier: Modifier = Modifier,
    highlight: Boolean = false,
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = if (highlight) {
                MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.55f)
            } else {
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
            },
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(text = title, style = MaterialTheme.typography.labelMedium)
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                color = if (highlight) OptlyOrange else MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

@Composable
private fun SubscriptionRow(sub: Subscription) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column {
                    Text(text = sub.name, style = MaterialTheme.typography.titleMedium)
                    Text(
                        text = sub.vendor,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    text = "$${"%.2f".format(sub.monthlyPrice)}/mo",
                    style = MaterialTheme.typography.titleSmall,
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AssistChip(
                    onClick = {},
                    label = { Text(sub.category.name.lowercase().replaceFirstChar { it.uppercase() }) },
                )
                if (sub.isLowUsage) {
                    AssistChip(
                        onClick = {},
                        label = { Text("Low usage") },
                    )
                }
            }
            Text(
                text = "Usage score: ${(sub.usageScore * 100).toInt()}%",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            LinearProgressIndicator(
                progress = { sub.usageScore.coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth(),
                color = if (sub.isLowUsage) OptlyOrange else MaterialTheme.colorScheme.tertiary,
                trackColor = MaterialTheme.colorScheme.surfaceVariant,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun SubscriptionsPreview() {
    OptlyTheme {
        SubscriptionsScreen()
    }
}
