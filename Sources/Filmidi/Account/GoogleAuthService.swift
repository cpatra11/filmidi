import AppKit
import Darwin
import Foundation

@MainActor
enum GoogleAuthService {

    private static let sessionTokenAccount = "filmidi-session-token"
    private static let sessionEmailAccount = "filmidi-session-email"
    private static let sessionNameAccount = "filmidi-session-name"

    static var sessionToken: String? {
        loadFromKeychain(account: sessionTokenAccount)
    }

    static var sessionEmail: String? {
        loadFromKeychain(account: sessionEmailAccount)
    }

    static var sessionName: String? {
        loadFromKeychain(account: sessionNameAccount)
    }

    static var isSignedIn: Bool {
        sessionToken != nil
    }

    static func signIn() async throws -> (email: String, name: String) {
        let clientID = QwenAccountService.shared.googleClientID
        guard !clientID.isEmpty, clientID != "YOUR_GOOGLE_CLIENT_ID" else {
            throw GoogleAuthError.notConfigured
        }

        let (fd, port) = try startTCPServer()
        defer { close(fd) }

        let redirectURI = "http://127.0.0.1:\(port)"
        let scope = "openid%20email%20profile"
        let authURL = URL(
            string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=\(scope)"
        )!

        NSWorkspace.shared.open(authURL)

        let code = try await acceptAndReadCode(fd: fd)

        let result = try await exchangeAuthCode(code, redirectUri: redirectURI)

        KeychainStore.save(result.token, account: sessionTokenAccount)
        KeychainStore.save(result.email, account: sessionEmailAccount)
        KeychainStore.save(result.name, account: sessionNameAccount)

        NotificationCenter.default.post(name: .filmidiSessionChanged, object: nil)

        return (result.email, result.name)
    }

    static func signOut() {
        KeychainStore.delete(account: sessionTokenAccount)
        KeychainStore.delete(account: sessionEmailAccount)
        KeychainStore.delete(account: sessionNameAccount)
        NotificationCenter.default.post(name: .filmidiSessionChanged, object: nil)
    }

    private static func startTCPServer() throws -> (Int32, UInt16) {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw serverError()
        }

        var on: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(0)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult >= 0 else {
            close(sock)
            throw serverError()
        }

        listen(sock, 5)

        var actualAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &actualAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(sock, $0, &addrLen)
            }
        }
        let actualPort = CFSwapInt16BigToHost(actualAddr.sin_port)
        guard actualPort != 0 else {
            close(sock)
            throw GoogleAuthError.serverError(POSIXError(.EADDRNOTAVAIL))
        }

        return (sock, actualPort)
    }

    private static func acceptAndReadCode(fd: Int32) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let client = accept(fd, nil, nil)
                guard client >= 0 else {
                    continuation.resume(throwing: serverError())
                    return
                }

                defer { close(client) }

                var buffer = [UInt8](repeating: 0, count: 8192)
                let n = read(client, &buffer, buffer.count)
                guard n > 0, let request = String(bytes: buffer[..<n], encoding: .utf8) else {
                    continuation.resume(throwing: GoogleAuthError.noAuthCode)
                    return
                }

                let parts = request.components(separatedBy: " ")
                guard parts.count >= 2,
                      let urlComps = URLComponents(string: "http://127.0.0.1\(parts[1])"),
                      let queryItems = urlComps.queryItems else {
                    continuation.resume(throwing: GoogleAuthError.noAuthCode)
                    return
                }

                if let error = queryItems.first(where: { $0.name == "error" })?.value {
                    continuation.resume(throwing: GoogleAuthError.oauthError(error))
                    return
                }

                guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: GoogleAuthError.noAuthCode)
                    return
                }

                let body = "<html><body><p>Signed in! You can close this window.</p><script>window.close()</script></body></html>"
                let response = "HTTP/1.1 200 OK\r\nContent-Length: \(body.utf8.count)\r\nContent-Type: text/html\r\n\r\n\(body)"
                response.withCString { ptr in
                    write(client, ptr, response.utf8.count)
                }

                continuation.resume(returning: code)
            }
        }
    }

    private static func exchangeAuthCode(_ authCode: String, redirectUri: String) async throws -> (token: String, email: String, name: String) {
        let backendURL = QwenAccountService.shared.hardcodedBackendURL
        let url = backendURL.appendingPathComponent("api/v1/auth/google")

        var request = URLRequest(url: url,
                                 timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "authCode": authCode,
            "redirectUri": redirectUri,
        ])

        Log.account.notice("auth: POST \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GoogleAuthError.api(status: 0, message: "Not an HTTP response")
        }

        Log.account.notice("auth: \(http.statusCode)")

        if http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GoogleAuthError.api(status: http.statusCode, message: body)
        }

        struct AuthResponse: Decodable {
            let token: String
            let email: String
            let name: String
        }

        let result = try JSONDecoder().decode(AuthResponse.self, from: data)
        return (result.token, result.email, result.name)
    }

    private static func serverError() -> GoogleAuthError {
        .serverError(POSIXError(POSIXErrorCode(rawValue: errno) ?? .EINVAL))
    }

    private static func loadFromKeychain(account: String) -> String? {
        #if DEBUG
        if let env = ProcessInfo.processInfo.environment["FILMIDI_SESSION_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        #endif
        return KeychainStore.load(account: account)
    }
}

enum GoogleAuthError: LocalizedError {
    case notConfigured
    case oauthError(String)
    case noAuthCode
    case serverError(Error)
    case api(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Google Sign-In is not configured."
        case .oauthError(let err): return "Google returned an error: \(err)"
        case .noAuthCode: return "No authorization code received from Google."
        case .serverError(let err): return "Local server error: \(err.localizedDescription)"
        case .api(_, let message): return message
        }
    }
}
