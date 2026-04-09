package com.optly.app.ui.finance

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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.optly.app.models.FinanceSnapshot
import com.optly.app.models.MicroInvestment
import com.optly.app.ui.theme.OptlyOrange
import com.optly.app.ui.theme.OptlyTheme

@Composable
fun FinanceScreen(modifier: Modifier = Modifier) {
    val snap = remember { FinanceSnapshot.Mock }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        contentPadding = PaddingValues(bottom = 96.dp, top = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Text(text = "Finance lens", style = MaterialTheme.typography.headlineSmall)
        }
        item {
            IncomeExpenseCard(snap = snap)
        }
        item {
            Text(text = "Budget categories", style = MaterialTheme.typography.titleMedium)
        }
        items(snap.categories, key = { it.id }) { cat ->
            BudgetRow(name = cat.name, spent = cat.spent, budget = cat.budget, color = colorFromHex(cat.colorHex))
        }
        item {
            Text(text = "AI savings ideas", style = MaterialTheme.typography.titleMedium)
        }
        items(snap.savingsSuggestions) { line ->
            SuggestionCard(text = line)
        }
        item {
            Text(text = "Micro-investments", style = MaterialTheme.typography.titleMedium)
        }
        items(snap.microInvestments, key = { it.id }) { m ->
            MicroInvestmentCard(m)
        }
    }
}

@Composable
private fun IncomeExpenseCard(snap: FinanceSnapshot) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = snap.monthLabel, style = MaterialTheme.typography.labelMedium)
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column {
                    Text(text = "Income", style = MaterialTheme.typography.bodySmall)
                    Text(
                        text = "$${"%,.0f".format(snap.income)}",
                        style = MaterialTheme.typography.titleLarge,
                    )
                }
                Column {
                    Text(text = "Expenses", style = MaterialTheme.typography.bodySmall)
                    Text(
                        text = "$${"%,.0f".format(snap.expenses)}",
                        style = MaterialTheme.typography.titleLarge,
                        color = OptlyOrange,
                    )
                }
            }
            Text(
                text = "Savings rate ${(snap.savingsRate * 100).toInt()}%",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.tertiary,
            )
        }
    }
}

@Composable
private fun BudgetRow(name: String, spent: Double, budget: Double, color: Color) {
    val ratio = if (budget <= 0) 0f else (spent / budget).toFloat().coerceIn(0f, 1.2f)
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(text = name, style = MaterialTheme.typography.titleSmall)
                Text(
                    text = "$${"%,.0f".format(spent)} / $${"%,.0f".format(budget)}",
                    style = MaterialTheme.typography.labelMedium,
                )
            }
            LinearProgressIndicator(
                progress = { ratio.coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth(),
                color = color,
                trackColor = MaterialTheme.colorScheme.surfaceVariant,
            )
        }
    }
}

@Composable
private fun SuggestionCard(text: String) {
    Card(
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f),
        ),
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(16.dp),
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun MicroInvestmentCard(m: MicroInvestment) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(text = m.label, style = MaterialTheme.typography.titleMedium)
            Text(
                text = "$${"%.2f".format(m.weeklyAmount)}/wk · ~${"%.1f".format(m.projectedYearGrowthPercent)}% projected",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Risk: ${m.riskLabel}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.tertiary,
            )
        }
    }
}

private fun colorFromHex(hex: String): Color {
    val clean = hex.removePrefix("#")
    val value = clean.toLong(16)
    return Color(0xFF000000L or value)
}

@Preview(showBackground = true)
@Composable
private fun FinancePreview() {
    OptlyTheme {
        FinanceScreen()
    }
}
