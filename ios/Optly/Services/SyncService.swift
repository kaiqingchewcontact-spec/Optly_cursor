//
//  SyncService.swift
//  Optly
//
//  Authenticated REST client for Supabase-style APIs, realtime channels, offline queue, and background sync.
//

import Foundation
import Combine
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

// MARK: - Errors

public enum SyncServiceError: LocalizedError, Sendable {
    case notAuthenticated
    case invalidURL
    case httpStatus(code: Int, body: String?)
    case encodingFailed
    case decodingFailed(underlying: Error)
    case realtimeNotConnected

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No valid session. Sign in before syncing."
        case .invalidURL:
            return "The sync URL is invalid."
        case .httpStatus(let code, let body):
            return "Request failed (\(code)): \(body ?? "")"
        case .encodingFailed:
            return "Failed to encode request body."
        case .decodingFailed(let e):
            return "Failed to decode response: \(e.localizedDescription)"
        case .realtimeNotConnected:
            return "Realtime channel is not connected."
        }
    }
}

// MARK: - Session

/// Bearer token and optional refresh hook for Supabase JWTs.
public struct SyncAuthSession: Sendable {
    public var accessToken: String
    public var refreshHandler: (@Sendable () async throws -> String)?

    public init(accessToken: String, refreshHandler: (@Sendable () async throws -> String)? = nil) {
        self.accessToken = accessToken
        self.refreshHandler = refreshHandler
    }
}

// MARK: - Queue

private struct PendingOperation: Codable, Sendable {
    var id: UUID
    var method: String
    var path: String
    var body: Data?
    var createdAt: Date
    var retryCount: Int
}

// MARK: - Conflict resolution

/// Last-write-wins using `updated_at` when both payloads are decodable as JSON objects with that key.
public enum ConflictResolutionStrategy: Sendable {
    case clientWins
    case serverWins
    case lastWriteWins(updatedAtKey: String)
}

// MARK: - Realtime (simplified)

/// Minimal realtime subscription using Server-Sent Events or long-poll could replace this; here we expose a Combine bridge.
public final class SupabaseRealtimeChannel: @unchecked Sendable {
    public let topic: String
    private let subject = PassthroughSubject<Data, Never>()
    private var task: URLSessionDataTask?

    public var publisher: AnyPublisher<Data, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(topic: String) {
        self.topic = topic
    }

    fileprivate func emit(_ data: Data) {
        subject.send(data)
    }

    fileprivate func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Sync service

/// Configured with project URL (e.g. `https://xxx.supabase.co`) and anon/service role usage via RLS.
public final class SyncService: @unchecked Sendable {

    public let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queueURL: URL
    private let conflictStrategy: ConflictResolutionStrategy

    private let authSubject = CurrentValueSubject<SyncAuthSession?, Never>(nil)
    private let queueLock = NSLock()
    private var pending: [PendingOperation] = []

    private var realtimeChannels: [String: SupabaseRealtimeChannel] = [:]
    private let realtimeLock = NSLock()

    public var authPublisher: AnyPublisher<SyncAuthSession?, Never> {
        authSubject.eraseToAnyPublisher()
    }

    /// Set after sign-in; clears on sign-out.
    public var currentSession: SyncAuthSession? {
        get { authSubject.value }
        set { authSubject.send(newValue) }
    }

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        conflictStrategy: ConflictResolutionStrategy = .lastWriteWins(updatedAtKey: "updated_at")
    ) {
        self.baseURL = baseURL
        self.session = session
        self.conflictStrategy = conflictStrategy
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        self.encoder = e
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
        self.queueURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OptlySyncQueue.json", isDirectory: false)
        loadQueueFromDisk()
    }

    // MARK: HTTP helpers

    private func authorizedRequest(url: URL, method: String, body: Data?) throws -> URLRequest {
        guard let sessionInfo = currentSession else { throw SyncServiceError.notAuthenticated }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(sessionInfo.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(sessionInfo.accessToken, forHTTPHeaderField: "apikey")
        req.httpBody = body
        return req
    }

    private func restURL(table: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false) else {
            throw SyncServiceError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw SyncServiceError.invalidURL }
        return url
    }

    private func perform(_ request: URLRequest, retryRefresh: Bool = true) async throws -> (Data, HTTPURLResponse) {
        var req = request
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SyncServiceError.httpStatus(code: -1, body: nil)
        }
        if http.statusCode == 401, retryRefresh, let refresh = currentSession?.refreshHandler {
            let newToken = try await refresh()
            currentSession = SyncAuthSession(accessToken: newToken, refreshHandler: refresh)
            req.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await perform(req, retryRefresh: false)
        }
        return (data, http)
    }

    // MARK: CRUD (PostgREST-style)

    public func fetch<T: Decodable>(_ type: T.Type, from table: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let url = try restURL(table: table, queryItems: queryItems)
        let req = try authorizedRequest(url: url, method: "GET", body: nil)
        let (data, http) = try await perform(req)
        guard (200..<300).contains(http.statusCode) else {
            throw SyncServiceError.httpStatus(code: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SyncServiceError.decodingFailed(underlying: error)
        }
    }

    public func insert<T: Encodable>(_ value: T, into table: String) async throws -> Data {
        let body = try encoder.encode(value)
        let url = try restURL(table: table)
        let req = try authorizedRequest(url: url, method: "POST", body: body)
        let (data, http) = try await perform(req)
        guard (200..<300).contains(http.statusCode) else {
            throw SyncServiceError.httpStatus(code: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        return data
    }

    public func upsert<T: Encodable>(_ value: T, into table: String, onConflict: String? = nil) async throws -> Data {
        var url = try restURL(table: table)
        if let onConflict {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw SyncServiceError.invalidURL
            }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "on_conflict", value: onConflict))
            components.queryItems = items
            guard let u = components.url else { throw SyncServiceError.invalidURL }
            url = u
        }
        var req = try authorizedRequest(url: url, method: "POST", body: try encoder.encode(value))
        req.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        let (data, http) = try await perform(req)
        guard (200..<300).contains(http.statusCode) else {
            throw SyncServiceError.httpStatus(code: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        return data
    }

    public func delete(from table: String, matching queryItems: [URLQueryItem]) async throws {
        let url = try restURL(table: table, queryItems: queryItems)
        let req = try authorizedRequest(url: url, method: "DELETE", body: nil)
        let (data, http) = try await perform(req)
        guard (200..<300).contains(http.statusCode) else {
            throw SyncServiceError.httpStatus(code: http.statusCode, body: String(data: data, encoding: .utf8))
        }
    }

    /// Merges JSON payloads per ``ConflictResolutionStrategy`` (best-effort for dictionary-like JSON).
    public func resolveConflict(clientJSON: Data, serverJSON: Data) throws -> Data {
        switch conflictStrategy {
        case .clientWins:
            return clientJSON
        case .serverWins:
            return serverJSON
        case .lastWriteWins(let key):
            guard
                let c = try JSONSerialization.jsonObject(with: clientJSON) as? [String: Any],
                let s = try JSONSerialization.jsonObject(with: serverJSON) as? [String: Any],
                let cDate = c[key] as? String,
                let sDate = s[key] as? String
            else {
                return serverJSON
            }
            if cDate >= sDate {
                return clientJSON
            }
            return serverJSON
        }
    }

    // MARK: Offline queue

    /// Enqueues a failed request for retry. `path` should be relative to ``baseURL`` (e.g. `rest/v1/habits`).
    public func enqueue(method: String, path: String, body: Data?) {
        queueLock.lock()
        pending.append(PendingOperation(id: UUID(), method: method, path: path, body: body, createdAt: Date(), retryCount: 0))
        queueLock.unlock()
        persistQueue()
    }

    public func flushPendingQueue(maxAttempts: Int = 5) async {
        queueLock.lock()
        var ops = pending
        queueLock.unlock()

        var remaining: [PendingOperation] = []
        for var op in ops {
            do {
                guard let opURL = URL(string: op.path, relativeTo: baseURL)?.absoluteURL else { continue }
                let req = try authorizedRequest(url: opURL, method: op.method, body: op.body)
                let (_, http) = try await perform(req)
                if (200..<300).contains(http.statusCode) {
                    continue
                }
                if http.statusCode == 409 {
                    // Conflict: optional merge — here we skip drop; host may resolve manually
                    remaining.append(op)
                    continue
                }
                op.retryCount += 1
                if op.retryCount < maxAttempts { remaining.append(op) }
            } catch {
                op.retryCount += 1
                if op.retryCount < maxAttempts { remaining.append(op) }
            }
        }
        queueLock.lock()
        pending = remaining
        queueLock.unlock()
        persistQueue()
    }

    private func loadQueueFromDisk() {
        guard let data = try? Data(contentsOf: queueURL),
              let list = try? JSONDecoder().decode([PendingOperation].self, from: data) else { return }
        pending = list
    }

    private func persistQueue() {
        queueLock.lock()
        let snap = pending
        queueLock.unlock()
        try? FileManager.default.createDirectory(at: queueURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: queueURL)
        }
    }

    // MARK: Background sync

    /// Register `com.optly.sync.refresh` in Info.plist `BGTaskSchedulerPermittedIdentifiers` and schedule from the app delegate.
    public func scheduleBackgroundSync(taskIdentifier: String) {
        #if canImport(BackgroundTasks)
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    // MARK: Realtime (stub)

    /// Returns a channel publisher; wire to your Supabase Realtime client or WebSocket implementation.
    public func subscribe(topic: String) -> SupabaseRealtimeChannel {
        realtimeLock.lock()
        defer { realtimeLock.unlock() }
        if let existing = realtimeChannels[topic] { return existing }
        let ch = SupabaseRealtimeChannel(topic: topic)
        realtimeChannels[topic] = ch
        return ch
    }

    public func unsubscribe(topic: String) {
        realtimeLock.lock()
        realtimeChannels[topic]?.cancel()
        realtimeChannels.removeValue(forKey: topic)
        realtimeLock.unlock()
    }
}
