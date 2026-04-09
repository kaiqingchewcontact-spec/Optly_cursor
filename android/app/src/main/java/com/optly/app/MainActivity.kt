package com.optly.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AttachMoney
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Subscriptions
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.optly.app.ui.dashboard.DashboardScreen
import com.optly.app.ui.finance.FinanceScreen
import com.optly.app.ui.focus.FocusScreen
import com.optly.app.ui.habits.HabitsScreen
import com.optly.app.ui.onboarding.OnboardingScreen
import com.optly.app.ui.settings.SettingsScreen
import com.optly.app.ui.subscriptions.SubscriptionsScreen
import com.optly.app.ui.theme.OptlyTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            OptlyTheme {
                OptlyRoot()
            }
        }
    }
}

private sealed class TopLevelRoute(val route: String, val label: String, val icon: ImageVector) {
    data object Dashboard : TopLevelRoute("dashboard", "Home", Icons.Filled.Home)
    data object Subscriptions : TopLevelRoute("subscriptions", "Subs", Icons.Filled.Subscriptions)
    data object Habits : TopLevelRoute("habits", "Habits", Icons.Filled.Psychology)
    data object Finance : TopLevelRoute("finance", "Finance", Icons.Filled.AttachMoney)
    data object Focus : TopLevelRoute("focus", "Focus", Icons.Filled.Timer)
    data object Settings : TopLevelRoute("settings", "Settings", Icons.Filled.Settings)
}

private val bottomNavItems = listOf(
    TopLevelRoute.Dashboard,
    TopLevelRoute.Subscriptions,
    TopLevelRoute.Habits,
    TopLevelRoute.Finance,
    TopLevelRoute.Focus,
    TopLevelRoute.Settings,
)

@Composable
private fun OptlyRoot() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination
    val showBottomBar = currentDestination?.route != "onboarding"

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                NavigationBar {
                    bottomNavItems.forEach { item ->
                        val selected = currentDestination?.hierarchy?.any { it.route == item.route } == true
                        NavigationBarItem(
                            icon = { Icon(item.icon, contentDescription = item.label) },
                            label = { Text(item.label) },
                            selected = selected,
                            onClick = {
                                navController.navigate(item.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                        )
                    }
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = "onboarding",
            modifier = Modifier.padding(innerPadding),
        ) {
            composable("onboarding") {
                OnboardingScreen(
                    onStartTrial = {
                        navController.navigate(TopLevelRoute.Dashboard.route) {
                            popUpTo("onboarding") { inclusive = true }
                        }
                    },
                )
            }
            composable(TopLevelRoute.Dashboard.route) { DashboardScreen() }
            composable(TopLevelRoute.Subscriptions.route) { SubscriptionsScreen() }
            composable(TopLevelRoute.Habits.route) { HabitsScreen() }
            composable(TopLevelRoute.Finance.route) { FinanceScreen() }
            composable(TopLevelRoute.Focus.route) { FocusScreen() }
            composable(TopLevelRoute.Settings.route) { SettingsScreen() }
        }
    }
}
