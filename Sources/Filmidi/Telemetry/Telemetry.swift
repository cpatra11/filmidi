import Foundation

/// Stub replacing Sentry-based telemetry. All methods are no-ops.
enum Telemetry {
    typealias Payload = [String: Any]

    static var isEnabled: Bool {
        get { false }
        set {}
    }

    static var enabledForCurrentLaunch: Bool { false }

    static func start() {}

    static func shortId(_ s: String) -> String { String(s.prefix(8)) }

    static func setExtra(value: Any?, key: String) {}

    static func breadcrumb(_ name: String?, category: String?, data: Payload?) {}

    static func logWarning(_ message: String?, category: String?, data: Payload?) {}

    static func logError(_ message: String?, category: String?, data: Payload?) {}

    static func logFault(_ message: String?, category: String?, data: Payload?) {}
}
