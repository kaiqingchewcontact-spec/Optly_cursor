package com.optly.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.optly.app.ui.OptlyApp
import com.optly.app.ui.theme.OptlyTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            OptlyTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    OptlyApp()
                }
            }
        }
    }
}
