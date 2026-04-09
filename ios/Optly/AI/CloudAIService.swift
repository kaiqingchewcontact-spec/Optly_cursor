//
//  CloudAIService.swift
//  Optly
//
//  Claude Messages API client with caching, rate limiting, streaming, and token accounting.
//

import Foundation

// MARK: - Errors

public enum CloudAIServiceError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidURL
    case httpStatus(Int, String?)
    case decodingFailed(Error)
    case rateLimited(retryAfter: TimeInterval?)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key is not configured."
        case .invalidURL:
            return "Invalid API URL."
        case .httpStatus(let c, let b):
            return "API error \(c): \(b ?? "")"
        case .decodingFailed(let e):
            return "Failed to decode API response: \(e.localizedDescription)"
        case .rateLimited(let t):
            return "Rate limited\(t.map { "; retry after \($0)s" } ?? "")."
        }
    }
}

// MARK: - Models

public struct ClaudeMessage: Sendable, Codable {
    public var role: String
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct CloudAIUsage: Sendable, Codable, Equatable {
    public var inputTokens: Int
    public var outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public struct CloudAIResponse: Sendable {
    public var text: String
    public var usage: CloudAIUsage
    public var model: String
}

// MARK: - Rate limiter

actor CloudAIRateLimiter {
    private var tokens: Int
    private let maxTokens: Int
    private let refillPerMinute: Int
    private var lastRefill: Date

    init(maxTokens: Int = 30, refillPerMinute: Int = 30) {
        self.maxTokens = maxTokens
        self.tokens = maxTokens
        self.refillPerMinute = refillPerMinute
        self.lastRefill = Date()
    }

    func acquire() async throws {
        refill()
        guard tokens > 0 else {
            throw CloudAIServiceError.rateLimited(retryAfter: 60)
        }
        tokens -= 1
    }

    private func refill() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefill)
        if elapsed >= 60 {
            let periods = Int(elapsed / 60)
            tokens = min(maxTokens, tokens + periods * refillPerMinute)
            lastRefill = now
        }
    }
}

// MARK: - Cache

private final class CloudAICache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: (Date, CloudAIResponse)] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 300) {
        self.ttl = ttl
    }

    func get(_ key: String) -> CloudAIResponse? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = storage[key], Date().timeIntervalSince(entry.0) < ttl else {
            storage.removeValue(forKey: key)
            return nil
        }
        return entry.1
    }

    func set(_ key: String, value: CloudAIResponse) {
        lock.lock()
        storage[key] = (Date(), value)
        lock.unlock()
    }
}

// MARK: - Service

/// Thin async client for `https://api.anthropic.com/v1/messages`. Supply API key via initializer or environment.
public final class CloudAIService: @unchecked Sendable {

    public var apiKey: String?
    public var model: String
    public var baseURL: URL
    private let session: URLSession
    private let limiter: CloudAIRateLimiter
    private let cache: CloudAICache
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private let usageStreamStorage: AsyncStream<CloudAIUsage>
    private let usageContinuation: AsyncStream<CloudAIUsage>.Continuation

    /// Yields token usage after each successful non-cached completion for cost tracking.
    public var usageStream: AsyncStream<CloudAIUsage> { usageStreamStorage }

    public init(
        apiKey: String? = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
        model: String = "claude-3-5-sonnet-20241022",
        baseURL: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.session = session
        self.limiter = CloudAIRateLimiter()
        self.cache = CloudAICache()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        var continuation: AsyncStream<CloudAIUsage>.Continuation!
        self.usageStreamStorage = AsyncStream<CloudAIUsage> { continuation = $0 }
        self.usageContinuation = continuation
    }

    // MARK: Non-streaming

    public func complete(
        system: String?,
        messages: [ClaudeMessage],
        maxTokens: Int = 1024,
        temperature: Double = 0.3,
        useCache: Bool = true
    ) async throws -> CloudAIResponse {
        guard let key = apiKey, !key.isEmpty else { throw CloudAIServiceError.missingAPIKey }

        let cacheKey = Self.cacheKey(system: system, messages: messages, model: model)
        if useCache, let hit = cache.get(cacheKey) {
            return hit
        }

        try await limiter.acquire()

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "messages": messages.map { ["role": $0.role, "content": [["type": "text", "text": $0.content]]] }
        ]
        if let system {
            body["system"] = system
        }

        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (respData, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw CloudAIServiceError.httpStatus(-1, nil)
        }
        if http.statusCode == 429 {
            let retry = http.value(forHTTPHeaderField: "retry-after").flatMap { TimeInterval($0) }
            throw CloudAIServiceError.rateLimited(retryAfter: retry)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CloudAIServiceError.httpStatus(http.statusCode, String(data: respData, encoding: .utf8))
        }

        let parsed = try Self.parseMessagesResponse(data: respData, decoder: decoder)
        if useCache {
            cache.set(cacheKey, value: parsed)
        }
        usageContinuation.yield(parsed.usage)
        return parsed
    }

    // MARK: Streaming

    public func streamCompletion(
        system: String?,
        messages: [ClaudeMessage],
        maxTokens: Int = 1024,
        temperature: Double = 0.3
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let key = self.apiKey, !key.isEmpty else {
                        continuation.finish(throwing: CloudAIServiceError.missingAPIKey)
                        return
                    }
                    try await self.limiter.acquire()

                    var body: [String: Any] = [
                        "model": self.model,
                        "max_tokens": maxTokens,
                        "temperature": temperature,
                        "stream": true,
                        "messages": messages.map { ["role": $0.role, "content": [["type": "text", "text": $0.content]]] }
                    ]
                    if let system { body["system"] = system }

                    let data = try JSONSerialization.data(withJSONObject: body)
                    var req = URLRequest(url: self.baseURL)
                    req.httpMethod = "POST"
                    req.httpBody = data
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue(key, forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let (bytes, response) = try await self.session.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw CloudAIServiceError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1, nil)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let d = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                              let type = json["type"] as? String else { continue }

                        if type == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: High-level prompts

    public func generateDailyBriefing(context: String) async throws -> CloudAIResponse {
        let system = "You are Optly, a concise personal assistant. Produce a structured daily briefing with sections: Health, Calendar, Money, Habits. Use bullet points. No medical or legal advice; encourage professional consultation when needed."
        let msg = ClaudeMessage(role: "user", content: context)
        return try await complete(system: system, messages: [msg], maxTokens: 1200)
    }

    public func financialDeepDive(context: String) async throws -> CloudAIResponse {
        let system = "You analyze personal finance summaries. Identify trends, subscriptions, and savings opportunities. Be specific and actionable. This is not financial advice."
        return try await complete(system: system, messages: [ClaudeMessage(role: "user", content: context)], maxTokens: 1500)
    }

    public func habitCoaching(context: String) async throws -> CloudAIResponse {
        let system = "You coach habits with empathy and evidence-based micro-steps. Keep responses under 200 words unless asked otherwise."
        return try await complete(system: system, messages: [ClaudeMessage(role: "user", content: context)], maxTokens: 600)
    }

    public func crossDomainInsights(context: String) async throws -> CloudAIResponse {
        let system = "Connect patterns across health, calendar, money, and habits. Prioritize high-impact, practical insights."
        return try await complete(system: system, messages: [ClaudeMessage(role: "user", content: context)], maxTokens: 900)
    }

    // MARK: Parsing

    private static func parseMessagesResponse(data: Data, decoder: JSONDecoder) throws -> CloudAIResponse {
        struct Root: Decodable {
            struct Content: Decodable {
                var type: String
                var text: String?
            }
            struct Usage: Decodable {
                var input_tokens: Int
                var output_tokens: Int
            }
            var content: [Content]
            var usage: Usage
            var model: String
        }
        do {
            let r = try decoder.decode(Root.self, from: data)
            let text = r.content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
            let usage = CloudAIUsage(inputTokens: r.usage.input_tokens, outputTokens: r.usage.output_tokens)
            return CloudAIResponse(text: text, usage: usage, model: r.model)
        } catch {
            throw CloudAIServiceError.decodingFailed(error)
        }
    }

    private static func cacheKey(system: String?, messages: [ClaudeMessage], model: String) -> String {
        let sys = system ?? ""
        let joined = messages.map { "\($0.role):\($0.content)" }.joined(separator: "|")
        return "\(model)::\(sys)::\(joined)".data(using: .utf8)!.base64EncodedString()
    }
}

