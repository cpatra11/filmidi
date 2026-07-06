import Foundation

/// REST backend for generation — talks to Hono backend instead of Convex
@MainActor
enum GenerationBackend {
    static func uploadReference(
        fileURL: URL,
        contentType: String,
    ) async throws -> String {
        let backendURL = QwenAccountService.shared.hardcodedBackendURL
        guard let token = QwenAccountService.shared.sessionToken else {
            throw GenerationBackendError.notConfigured
        }

        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"ref.\(fileURL.pathExtension)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/uploads"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "upload_failed", message: body)
        }

        struct UploadResponse: Decodable {
            let url: String
        }
        let result = try JSONDecoder().decode(UploadResponse.self, from: data)
        return result.url
    }

    static func submit(
        model: String,
        params: BackendGenerationParams,
        projectId: String? = nil,
    ) async throws -> String {
        let backendURL = QwenAccountService.shared.hardcodedBackendURL
        guard let token = QwenAccountService.shared.sessionToken else {
            throw GenerationBackendError.notConfigured
        }

        let body = try JSONEncoder().encode(params)


        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/generations"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "submit_failed", message: body)
        }

        struct SubmitResponse: Decodable {
            let taskId: String
            let status: String
        }
        let result = try JSONDecoder().decode(SubmitResponse.self, from: data)
        return result.taskId
    }

    static func pollTask(taskId: String) async throws -> BackendGenerationJob {
        let backendURL = QwenAccountService.shared.hardcodedBackendURL
        guard let token = QwenAccountService.shared.sessionToken else {
            throw GenerationBackendError.notConfigured
        }

        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/tasks/\(taskId)"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "poll_failed", message: body)
        }

        return try JSONDecoder().decode(BackendGenerationJob.self, from: data)
    }
}

// MARK: - Backend generation types

enum BackendGenerationParams: Encodable, Sendable {
    case video(VideoGenerationParams)
    case image(ImageGenerationParams)
    case audio(AudioGenerationParams)
    case upscale(UpscaleGenerationParams)

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .video(let p): try c.encode(p)
        case .image(let p): try c.encode(p)
        case .audio(let p): try c.encode(p)
        case .upscale(let p): try c.encode(p)
        }
    }

    enum CodingKeys: String, CodingKey {
        case model, prompt, duration, aspectRatio, resolution, quality
        case voice, lyrics, styleInstructions, instrumental
        case referenceImageURLs, referenceVideoURLs, referenceAudioURLs
        case startFrameURL, endFrameURL, sourceVideoURL
    }
}

enum BackendGenerationStatus: String, Decodable, Sendable {
    case queued, running, succeeded, failed
}

struct BackendGenerationJob: Decodable, Sendable {
    let taskId: String
    let status: BackendGenerationStatus
    let resultUrls: [String]?
    let errorMessage: String?
}

enum GenerationBackendError: LocalizedError {
    case notConfigured
    case transport(String)
    case api(status: Int, code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Filmidi backend not configured."
        case .transport(let s): return s
        case .api(_, _, let message): return message
        }
    }
}
