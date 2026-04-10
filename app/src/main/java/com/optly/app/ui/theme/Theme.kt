package com.optly.app.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val LightColors = lightColorScheme(
    primary = DeepBlue,
    onPrimary = Mist,
    primaryContainer = SkyBlue,
    onPrimaryContainer = Slate,
    secondary = SkyBlue,
    onSecondary = Slate,
    background = Mist,
    onBackground = Slate,
    surface = Mist,
    onSurface = Slate,
    surfaceVariant = Color(0xFFE2E8F0),
    onSurfaceVariant = Color(0xFF475569),
)

private val DarkColors = darkColorScheme(
    primary = SkyBlue,
    onPrimary = Slate,
    primaryContainer = DeepBlue,
    onPrimaryContainer = Mist,
    secondary = DeepBlue,
    onSecondary = Mist,
    background = Slate,
    onBackground = Mist,
    surface = Slate,
    onSurface = Mist,
    surfaceVariant = Color(0xFF334155),
    onSurfaceVariant = Color(0xFFCBD5E1),
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

    MaterialTheme(
        colorScheme = colorScheme,
        typography = OptlyTypography,
        content = content,
    )
}
