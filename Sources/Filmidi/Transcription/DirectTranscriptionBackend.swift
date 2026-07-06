import Foundation

/// Direct Qwen Cloud transcription — no Hono backend needed.
@MainActor
enum DirectTranscriptionBackend {
    private static let baseURL = URL(string: "https://dashscope-intl.aliyuncs.com")!

    static func submit(
        audioURL: String,
        durationSeconds: Double,
        language: String?,
        apiKey: String
    ) async throws -> BackendTranscriptionSubmit {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/services/asr/transcription/asr-task"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "paraformer-realtime-v2",
            "input": ["file_url": audioURL],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "transcription_submit_failed", message: body)
        }

        struct SubmitResponse: Decodable {
            let output: Output
            struct Output: Decodable {
                let taskId: String
                let taskStatus: String
            }
        }

        let result = try JSONDecoder().decode(SubmitResponse.self, from: data)
        return BackendTranscriptionSubmit(taskId: result.output.taskId)
    }

    static func pollTask(taskId: String, apiKey: String) async throws -> BackendTranscriptionJob {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/tasks/\(taskId)"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "transcription_poll_failed", message: body)
        }

        struct PollResponse: Decodable {
            let output: Output
            struct Output: Decodable {
                let taskId: String
                let taskStatus: String
                let result: TranscriptionResultRef?
                struct TranscriptionResultRef: Decodable {
                    let transcription: TranscriptionURL?
                    struct TranscriptionURL: Decodable {
                        let url: String?
                    }
                }
            }
        }

        let result = try JSONDecoder().decode(PollResponse.self, from: data)
        let qwenStatus = result.output.taskStatus

        let status: BackendTranscriptionStatus
        switch qwenStatus {
        case "SUCCEEDED": status = .succeeded
        case "FAILED": status = .failed
        default: status = .running
        }

        return BackendTranscriptionJob(
            taskId: result.output.taskId,
            status: status,
            errorMessage: nil
        )
    }

    static func result(taskId: String, apiKey: String) async throws -> TranscriptionResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/tasks/\(taskId)"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "transcription_result_failed", message: body)
        }

        struct ResultResponse: Decodable {
            let output: Output
            struct Output: Decodable {
                let result: TranscriptionResultRef?
                struct TranscriptionResultRef: Decodable {
                    let transcription: TranscriptionURL?
                    struct TranscriptionURL: Decodable {
                        let url: String
                    }
                }
            }
        }

        let result = try JSONDecoder().decode(ResultResponse.self, from: data)
        guard let urlString = result.output.result?.transcription?.url,
              let url = URL(string: urlString) else {
            throw TranscriptionBackendError.failed("No transcription result URL")
        }

        let (transData, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(TranscriptionResult.self, from: transData)
    }

    static func waitForResult(taskId: String, apiKey: String) async throws -> TranscriptionResult {
        let pollInterval: UInt64 = 2_000_000_000
        while true {
            let job = try await pollTask(taskId: taskId, apiKey: apiKey)
            switch job.status {
            case .succeeded:
                return try await result(taskId: taskId, apiKey: apiKey)
            case .failed:
                throw TranscriptionBackendError.failed(job.errorMessage ?? "Transcription failed")
            case .queued, .running:
                try await Task.sleep(nanoseconds: pollInterval)
            }
        }
    }
}
