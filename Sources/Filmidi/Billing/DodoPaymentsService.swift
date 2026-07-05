import AppKit
import AuthenticationServices
import Foundation

@MainActor
enum DodoPaymentsService {
    static var backendURL: URL { QwenAccountService.shared.hardcodedBackendURL }

    static func createCheckoutSession(priceId: String) async throws -> URL {
        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/billing/checkout"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = QwenAccountService.shared.sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = ["priceId": priceId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw BillingError.api(status: http.statusCode, message: body)
        }

        struct CheckoutResponse: Decodable {
            let url: String
        }

        let result = try JSONDecoder().decode(CheckoutResponse.self, from: data)
        guard let url = URL(string: result.url) else {
            throw BillingError.invalidURL
        }
        return url
    }

    static func getCustomerPortalURL() async throws -> URL {
        guard let token = QwenAccountService.shared.sessionToken else {
            throw BillingError.notAuthenticated
        }

        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/billing/portal"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw BillingError.api(status: http.statusCode, message: body)
        }

        struct PortalResponse: Decodable {
            let url: String
        }

        let result = try JSONDecoder().decode(PortalResponse.self, from: data)
        guard let url = URL(string: result.url) else {
            throw BillingError.invalidURL
        }
        return url
    }

    static func getSubscriptionStatus() async throws -> SubscriptionInfo {
        guard let token = QwenAccountService.shared.sessionToken else {
            throw BillingError.notAuthenticated
        }

        var request = URLRequest(url: backendURL.appendingPathComponent("api/v1/billing/subscription"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw BillingError.api(status: http.statusCode, message: body)
        }

        return try JSONDecoder().decode(SubscriptionInfo.self, from: data)
    }
}

struct SubscriptionInfo: Decodable, Sendable {
    let plan: String
    let status: String
    let expiresAt: String?
    let creditsRemaining: Int
}

enum BillingError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case invalidURL
    case api(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Filmidi backend not configured."
        case .notAuthenticated: return "No backend API key. Subscribe first."
        case .invalidURL: return "Invalid response URL."
        case .api(_, let message): return message
        }
    }
}

@MainActor
final class DodoPaymentsSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func start(url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "filmidi"
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            session.presentationContextProvider = self
            session.start()
            self.session = session
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first!
    }
}
