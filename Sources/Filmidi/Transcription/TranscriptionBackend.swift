import Foundation

@MainActor
enum TranscriptionBackend {
    static func submit(
        audioURL: String,
        durationSeconds: Double,
        language: String?,
        projectId: String?
    ) async throws -> BackendTranscriptionSubmit {
        let backendURL = QwenAccountService.shared.hardcodedBackendURL
        guard let token = QwenAccountService.shared.sessionToken else {
            throw GenerationBackendError.notConfigured
        }

        let body = try JSONSerialization.data(withJSONObject: [
            "audioURL": audioURL,
            "durationSeconds": durationSeconds,
            "language": language as Any,
            "projectId": projectId as Any,
        ] as [String: Any])

        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/transcriptions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "transcription_submit_failed", message: body)
        }

        return try JSONDecoder().decode(BackendTranscriptionSubmit.self, from: data)
    }

    static func pollTask(taskId: String) async throws -> BackendTranscriptionJob {
        let backendURL = QwenAccountService.shared.hardcodedBackendURL
        guard let token = QwenAccountService.shared.sessionToken else {
            throw GenerationBackendError.notConfigured
        }

        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/transcriptions/\(taskId)"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "transcription_poll_failed", message: body)
        }

        return try JSONDecoder().decode(BackendTranscriptionJob.self, from: data)
    }

    static func result(jobId: String) async throws -> TranscriptionResult {
        let response = try await resultRef(jobId: jobId)
        guard let url = URL(string: response.resultUrl) else {
            throw TranscriptionBackendError.failed("Invalid transcription result URL")
        }
        let (data, urlResponse) = try await URLSession.shared.data(from: url)
        guard let http = urlResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TranscriptionBackendError.failed("Could not download transcription result")
        }
        return try JSONDecoder().decode(TranscriptionResult.self, from: data)
    }

    private static func resultRef(jobId: String) async throws -> BackendTranscriptionResultRef {
        let backendURL = QwenAccountService.shared.hardcodedBackendURL
        guard let token = QwenAccountService.shared.sessionToken else {
            throw GenerationBackendError.notConfigured
        }

        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/transcriptions/\(jobId)/result"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "transcription_result_failed", message: body)
        }

        return try JSONDecoder().decode(BackendTranscriptionResultRef.self, from: data)
    }

    static func waitForResult(jobId: String) async throws -> TranscriptionResult {
        let pollInterval: UInt64 = 2_000_000_000
        while true {
            let job = try await pollTask(taskId: jobId)
            switch job.status {
            case .succeeded:
                return try await result(jobId: jobId)
            case .failed:
                throw TranscriptionBackendError.failed(job.errorMessage ?? "Transcription failed")
            case .queued, .running:
                try await Task.sleep(nanoseconds: pollInterval)
            }
        }
    }
}

enum BackendTranscriptionStatus: String, Decodable, Sendable {
    case queued, running, succeeded, failed
}

struct BackendTranscriptionSubmit: Decodable, Sendable {
    let taskId: String
    var jobId: String { taskId }
}

struct BackendTranscriptionJob: Decodable, Sendable {
    let taskId: String
    let status: BackendTranscriptionStatus
    let errorMessage: String?
}

private struct BackendTranscriptionResultRef: Decodable, Sendable {
    let resultUrl: String
}

enum TranscriptionBackendError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}
