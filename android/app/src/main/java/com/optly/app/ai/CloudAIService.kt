package com.optly.app.ai

import com.optly.app.BuildConfig
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CloudAIService @Inject constructor(
    private val httpClient: HttpClient,
    private val json: Json,
) {

    suspend fun completeBriefing(prompt: String): Result<String> = runCatching {
        val key = BuildConfig.CLAUDE_API_KEY
        if (key.isBlank()) {
            return@runCatching prompt
        }
        val request = ClaudeRequest(
            model = "claude-3-5-sonnet-20241022",
            maxTokens = 512,
            messages = listOf(ClaudeMessage(role = "user", content = prompt)),
        )
        val response = httpClient.post("${BuildConfig.CLAUDE_API_BASE.trimEnd('/')}/v1/messages") {
            contentType(ContentType.Application.Json)
            header("x-api-key", key)
            header("anthropic-version", "2023-06-01")
            setBody(json.encodeToString(ClaudeRequest.serializer(), request))
        }.body<ClaudeResponse>()
        response.content
            .filter { it.type == "text" && !it.text.isNullOrBlank() }
            .joinToString("\n") { it.text!! }
    }
}

@Serializable
private data class ClaudeRequest(
    val model: String,
    @SerialName("max_tokens") val maxTokens: Int,
    val messages: List<ClaudeMessage>,
)

@Serializable
private data class ClaudeMessage(
    val role: String,
    val content: String,
)

@Serializable
private data class ClaudeResponse(
    val content: List<ClaudeContentBlock>,
)

@Serializable
private data class ClaudeContentBlock(
    val type: String,
    val text: String? = null,
)
