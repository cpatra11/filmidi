import Foundation

/// Direct Qwen Cloud generation — no Hono backend needed.
/// Wraps Qwen REST APIs for image, video, and audio generation.
@MainActor
enum DirectGenerationBackend {
    private static let baseURL = URL(string: "https://dashscope-intl.aliyuncs.com")!

    static func submit(
        model: String,
        params: BackendGenerationParams,
        apiKey: String
    ) async throws -> String {
        if model.hasPrefix("sonilo-") || model.hasPrefix("mirelo-") || model.hasPrefix("hitpaw-") {
            throw GenerationBackendError.api(status: 400, code: "backend_only", message: "Model '\(model)' requires the Filmidi backend. Sign in and subscribe to use it.")
        }
        let body = try buildQwenBody(model: model, params: params)

        var request = URLRequest(url: qwenEndpoint(model: model, for: params))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if isAsyncGeneration(model: model, params: params) {
            request.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "qwen_submit_failed", message: body)
        }

        struct SubmitResponse: Decodable {
            let output: Output
            struct Output: Decodable {
                let taskId: String?
                let taskStatus: String?
                let results: [Result]?
                struct Result: Decodable {
                    let urls: [String]?
                }
            }
        }

        let result = try JSONDecoder().decode(SubmitResponse.self, from: data)
        if let taskId = result.output.taskId {
            return taskId
        }
        if let results = result.output.results, let urls = results.first?.urls, let first = urls.first {
            return first
        }
        return result.output.taskStatus ?? "unknown"
    }

    static func pollTask(taskId: String, apiKey: String) async throws -> BackendGenerationJob {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/tasks/\(taskId)"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GenerationBackendError.api(status: http.statusCode, code: "qwen_poll_failed", message: body)
        }

        struct PollResponse: Decodable {
            let output: Output
            struct Output: Decodable {
                let taskId: String
                let taskStatus: String
                let results: [Result]?
                struct Result: Decodable {
                    let url: String?
                }
            }
        }

        let result = try JSONDecoder().decode(PollResponse.self, from: data)
        let qwenStatus = result.output.taskStatus

        let status: BackendGenerationStatus
        switch qwenStatus {
        case "SUCCEEDED": status = .succeeded
        case "FAILED": status = .failed
        case "PENDING": status = .queued
        default: status = .running
        }

        return BackendGenerationJob(
            taskId: result.output.taskId,
            status: status,
            resultUrls: result.output.results?.compactMap { $0.url },
            errorMessage: nil
        )
    }

    private static func qwenEndpoint(model: String, for params: BackendGenerationParams) -> URL {
        if model == "wan2.7-image-pro" {
            return baseURL.appendingPathComponent("api/v1/services/aigc/wanx-image-generation/generation")
        }
        if model.hasPrefix("happyhorse-") {
            let suffix: String
            if model == "happyhorse-1.1-i2v" {
                suffix = "happyhorse-image-to-video"
            } else if model == "happyhorse-1.1-r2v" {
                suffix = "happyhorse-reference-to-video"
            } else {
                suffix = "happyhorse-text-to-video"
            }
            return baseURL.appendingPathComponent("api/v1/services/aigc/video-generation/\(suffix)")
        }
        switch params {
        case .image, .audio:
            return baseURL.appendingPathComponent("api/v1/services/aigc/multimodal-generation/generation")
        case .video, .upscale:
            return baseURL.appendingPathComponent("api/v1/services/aigc/video-generation/video-synthesis")
        }
    }

    private static func isAsyncGeneration(model: String, params: BackendGenerationParams) -> Bool {
        if model.hasPrefix("happyhorse-") { return true }
        switch params {
        case .video, .upscale: return true
        case .image, .audio: return false
        }
    }

    private static func buildQwenBody(model: String, params: BackendGenerationParams) throws -> [String: Any] {
        switch params {
        case .image(let p):
            return [
                "model": model,
                "input": ["prompt": p.prompt],
                "parameters": [
                    "size": p.resolution ?? "1024x1024",
                    "n": p.numImages,
                ],
            ]
        case .video(let p):
            var input: [String: Any] = ["prompt": p.prompt]
            if let url = p.sourceVideoURL { input["video_url"] = url }
            if let url = p.startFrameURL { input["start_frame_url"] = url }
            if let url = p.endFrameURL { input["end_frame_url"] = url }
            if !p.referenceImageURLs.isEmpty { input["image_url"] = p.referenceImageURLs.first }
            return [
                "model": model,
                "input": input,
                "parameters": [
                    "duration": p.duration,
                    "size": p.resolution ?? "1280x720",
                ],
            ]
        case .audio(let p):
            var parameters: [String: Any] = [
                "voice": p.voice ?? "longxiaochun",
            ]
            if let lyrics = p.lyrics, !lyrics.isEmpty {
                parameters["lyrics"] = lyrics
            }
            if let style = p.styleInstructions, !style.isEmpty {
                parameters["style_instructions"] = style
            }
            if p.instrumental {
                parameters["instrumental"] = true
            }
            if let duration = p.durationSeconds {
                parameters["duration"] = duration
            }

            var input: [String: Any] = ["text": p.prompt]
            if let url = p.videoURL {
                input["video_url"] = url
            }

            return [
                "model": model,
                "input": input,
                "parameters": parameters,
            ]
        case .upscale(let p):
            return [
                "model": model,
                "input": ["video_url": p.sourceURL],
                "parameters": [:],
            ]
        }
    }
}
