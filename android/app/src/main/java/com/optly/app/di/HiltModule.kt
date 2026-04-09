package com.optly.app.di

import android.content.Context
import androidx.room.Room
import com.optly.app.data.OptlyDatabase
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import io.ktor.client.HttpClient
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object HiltModule {

    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    @Provides
    @Singleton
    fun provideHttpClient(json: Json): HttpClient =
        HttpClient(Android) {
            install(ContentNegotiation) {
                json(json)
            }
        }

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): OptlyDatabase =
        Room.databaseBuilder(context, OptlyDatabase::class.java, "optly.db")
            .fallbackToDestructiveMigration()
            .build()
}
