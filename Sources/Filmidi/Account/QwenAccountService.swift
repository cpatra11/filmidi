import Foundation

extension Notification.Name {
    static let qwenAPIKeyChanged = Notification.Name("qwenAPIKeyChanged")
    static let filmidiModeChanged = Notification.Name("filmidiModeChanged")
    static let filmidiSessionChanged = Notification.Name("filmidiSessionChanged")
}

enum QwenKeychain {
    private static let keyAccount = "qwen-api-key"

    static func saveKey(_ key: String) {
        KeychainStore.save(key, account: keyAccount)
        NotificationCenter.default.post(name: .qwenAPIKeyChanged, object: nil)
    }

    static func loadKey() -> String? {
        #if DEBUG
        if let env = ProcessInfo.processInfo.environment["QWEN_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        #endif
        return KeychainStore.load(account: keyAccount)
    }

    static func deleteKey() {
        KeychainStore.delete(account: keyAccount)
        NotificationCenter.default.post(name: .qwenAPIKeyChanged, object: nil)
    }
}

enum FilmidiMode: String, Sendable {
    case direct
    case backend

    var label: String {
        switch self {
        case .direct: "Direct Qwen API"
        case .backend: "Filmidi Backend (Subscription)"
        }
    }

    var description: String {
        switch self {
        case .direct: "Use your own Qwen API key directly."
        case .backend: "Use the Filmidi backend with your subscription."
        }
    }
}

@MainActor
final class QwenAccountService: NSObject {
    static let shared = QwenAccountService()

    let qwenBaseURL = URL(string: "https://dashscope-intl.aliyuncs.com")!
    let anthropicCompatURL = URL(string: "https://dashscope-intl.aliyuncs.com/apps/anthropic")!

    let hardcodedBackendURL: URL = {
        #if DEBUG
        if let env = ProcessInfo.processInfo.environment["FILMIDI_BACKEND_URL"],
           let url = URL(string: env) {
            return url
        }
        #endif
        return URL(string: "http://localhost:3000")!
    }()

    let googleClientID: String = {
        #if DEBUG
        if let env = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"],
           !env.isEmpty {
            return env
        }
        #endif
        return "YOUR_GOOGLE_CLIENT_ID"
    }()

    private(set) var mode: FilmidiMode = .direct
    private(set) var qwenAPIKey: String?

    var sessionToken: String? { GoogleAuthService.sessionToken }
    var sessionEmail: String? { GoogleAuthService.sessionEmail }
    var sessionName: String? { GoogleAuthService.sessionName }

    var isConfigured: Bool {
        switch mode {
        case .direct: qwenAPIKey != nil
        case .backend: sessionToken != nil
        }
    }

    var canUseDirectAPI: Bool { qwenAPIKey != nil }

    private var keyObserver: NSObjectProtocol?
    private var modeObserver: NSObjectProtocol?
    private var sessionObserver: NSObjectProtocol?

    private override init() {
        super.init()
        reload()
        keyObserver = NotificationCenter.default.addObserver(
            forName: .qwenAPIKeyChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        modeObserver = NotificationCenter.default.addObserver(
            forName: .filmidiModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        sessionObserver = NotificationCenter.default.addObserver(
            forName: .filmidiSessionChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    private func reload() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let apiKey = await Task.detached(priority: .utility) { QwenKeychain.loadKey() }.value
            let savedMode = UserDefaults.standard.string(forKey: "filmidiMode") ?? "direct"

            self.qwenAPIKey = apiKey
            self.mode = FilmidiMode(rawValue: savedMode) ?? .direct

            Log.account.notice("mode=\(self.mode.rawValue) hasQwenKey=\(apiKey != nil) hasSession=\(sessionToken != nil)")
        }
    }

    func setMode(_ newMode: FilmidiMode) {
        UserDefaults.standard.set(newMode.rawValue, forKey: "filmidiMode")
        NotificationCenter.default.post(name: .filmidiModeChanged, object: nil)
    }
}
