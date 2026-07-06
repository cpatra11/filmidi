import Foundation

struct FilmidiClient: AgentClient {
    let backendURL: URL
    let sessionToken: String
    let model: AnthropicModel
    var maxTokens: Int = 8192

    private static let maxRetries = 3
    private static let streamTimeout: UInt64 = 300_000_000_000
    private static let baseRetryDelay: UInt64 = 1_000_000_000

    func stream(
        system: String,
        tools: [AnthropicToolSchema],
        messages: [AnthropicMessage]
    ) -> AsyncThrowingStream<AnthropicStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await runWithRetry(system: system, tools: tools, messages: messages, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runWithRetry(
        system: String,
        tools: [AnthropicToolSchema],
        messages: [AnthropicMessage],
        continuation: AsyncThrowingStream<AnthropicStreamEvent, Error>.Continuation
    ) async throws {
        var lastError: Error = AnthropicClientError.streamError("Max retries exceeded")

        for attempt in 0..<Self.maxRetries {
            guard !Task.isCancelled else { throw CancellationError() }
            if attempt > 0 {
                let jitter = Double.random(in: 0.5...1.0)
                let delay = UInt64(Double(Self.baseRetryDelay) * pow(2.0, Double(attempt - 1)) * jitter)
                try await Task.sleep(nanoseconds: min(delay, 30_000_000_000))
            }
            do {
                try await runOnce(system: system, tools: tools, messages: messages, continuation: continuation)
                return
            } catch let err as AnthropicClientError {
                if case .httpError(let status, _) = err, status == 429 {
                    lastError = err
                    continue
                }
                throw err
            }
        }

        throw lastError
    }

    private func runOnce(
        system: String,
        tools: [AnthropicToolSchema],
        messages: [AnthropicMessage],
        continuation: AsyncThrowingStream<AnthropicStreamEvent, Error>.Continuation
    ) async throws {
        guard !sessionToken.isEmpty else { throw AnthropicClientError.missingAPIKey }

        let body = AnthropicRequestBody.build(
            model: model, maxTokens: maxTokens, system: system, tools: tools, messages: messages
        )

        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/agent/stream"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("text/event-stream", forHTTPHeaderField: "accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicClientError.streamError("Invalid response")
        }

        if http.statusCode == 429 {
            var body = ""
            for try await line in bytes.lines { body += line + "\n" }
            throw AnthropicClientError.httpError(status: 429, body: body)
        }

        if http.statusCode >= 400 {
            var body = ""
            for try await line in bytes.lines { body += line + "\n" }
            throw AnthropicClientError.httpError(status: http.statusCode, body: body)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await AnthropicSSE.parse(bytes: bytes, continuation: continuation)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.streamTimeout)
                throw CancellationError()
            }
            try await group.next()
            group.cancelAll()
        }
    }
}
