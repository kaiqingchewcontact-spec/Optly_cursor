package com.optly.app.services

import com.optly.app.BuildConfig
import com.optly.app.data.EntityMappers
import com.optly.app.data.OptlyDatabase
import com.optly.app.models.DailyBriefing
import com.optly.app.models.Habit
import com.optly.app.models.InsightCard
import com.optly.app.models.Subscription
import com.optly.app.models.User
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import javax.inject.Inject

@javax.inject.Singleton
class SyncService @Inject constructor(
    private val httpClient: HttpClient,
    private val database: OptlyDatabase,
    private val json: Json,
) {

    suspend fun pushUserSnapshot(user: User): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            database.userProfileDao().upsert(EntityMappers.run { user.toEntity() })
            val url = "${BuildConfig.SUPABASE_URL.trimEnd('/')}/rest/v1/user_snapshots"
            httpClient.post(url) {
                contentType(ContentType.Application.Json)
                headers {
                    append("apikey", BuildConfig.SUPABASE_ANON_KEY)
                    append("Authorization", "Bearer ${BuildConfig.SUPABASE_ANON_KEY}")
                    append("Prefer", "resolution=merge-duplicates")
                }
                setBody(
                    JsonObject(
                        mapOf(
                            "id" to JsonPrimitive(user.id),
                            "payload" to JsonPrimitive(json.encodeToString(User.serializer(), user)),
                        ),
                    ),
                )
            }
        }.map { }
    }

    suspend fun pullRemoteInsights(): List<InsightCard> = withContext(Dispatchers.IO) {
        runCatching {
            val url = "${BuildConfig.SUPABASE_URL.trimEnd('/')}/rest/v1/insights?select=payload"
            val rows = httpClient.get(url) {
                headers {
                    append("apikey", BuildConfig.SUPABASE_ANON_KEY)
                    append("Authorization", "Bearer ${BuildConfig.SUPABASE_ANON_KEY}")
                }
            }.body<List<InsightRow>>()
            rows.mapNotNull { row ->
                runCatching { json.decodeFromString(InsightCard.serializer(), row.payload) }.getOrNull()
            }
        }.getOrElse { emptyList() }
    }

    suspend fun cacheBriefing(briefing: DailyBriefing) {
        withContext(Dispatchers.IO) {
            database.dailyBriefingDao().upsert(EntityMappers.run { briefing.toEntity() })
        }
    }

    suspend fun cacheHabits(habits: List<Habit>) {
        withContext(Dispatchers.IO) {
            database.habitDao().upsertAll(habits.map { EntityMappers.run { it.toEntity() } })
        }
    }

    suspend fun cacheSubscriptions(subs: List<Subscription>) {
        withContext(Dispatchers.IO) {
            database.subscriptionDao().upsertAll(subs.map { EntityMappers.run { it.toEntity() } })
        }
    }
}

@Serializable
private data class InsightRow(
    val payload: String,
)
