package com.optly.app.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val LightColors = lightColorScheme(
    primary = OptlyIndigo,
    onPrimary = Color.White,
    primaryContainer = OptlyIndigo.copy(alpha = 0.12f),
    onPrimaryContainer = OptlyTextPrimaryLight,
    secondary = OptlyPurple,
    onSecondary = Color.White,
    tertiary = OptlyTeal,
    onTertiary = Color.White,
    background = OptlyBackgroundLight,
    onBackground = OptlyTextPrimaryLight,
    surface = OptlySurfaceLight,
    onSurface = OptlyTextPrimaryLight,
    surfaceVariant = Color(0xFFEEF2FF),
    onSurfaceVariant = OptlyTextSecondaryLight,
    error = OptlyError,
    onError = Color.White,
    outline = Color(0xFFCBD5E1),
    outlineVariant = Color(0xFFE2E8F0),
)

private val DarkColors = darkColorScheme(
    primary = OptlyIndigo,
    onPrimary = Color.White,
    primaryContainer = OptlyIndigoDark,
    onPrimaryContainer = Color(0xFFE0E7FF),
    secondary = OptlyPurple,
    onSecondary = Color.White,
    tertiary = OptlyTeal,
    onTertiary = Color(0xFF042F2E),
    background = OptlyBackgroundDark,
    onBackground = OptlyTextPrimaryDark,
    surface = OptlySurfaceDark,
    onSurface = OptlyTextPrimaryDark,
    surfaceVariant = OptlySurfaceVariantDark,
    onSurfaceVariant = OptlyTextSecondaryDark,
    error = OptlyError,
    onError = Color.White,
    outline = Color(0xFF334155),
    outlineVariant = Color(0xFF1E293B),
)

@Composable
fun OptlyTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColors
        else -> LightColors
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as? android.app.Activity)?.window ?: return@SideEffect
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = OptlyTypography,
        content = content,
    )
}
