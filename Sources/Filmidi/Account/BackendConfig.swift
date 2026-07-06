import Foundation

enum BackendConfig {
    static var httpURL: URL? {
        string("FilmidiBackendURL").flatMap { URL(string: $0) }
    }

    static var isConfigured: Bool { httpURL != nil }

    private static func string(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else { return nil }
        return value
    }
}
