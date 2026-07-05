import Foundation

struct TranscriptionModelConfig: Identifiable, Sendable {
    @MainActor
    static var allModels: [TranscriptionModelConfig] { ModelCatalog.shared.transcription }

    let entry: CatalogEntry
    let caps: TranscriptionCaps

    var id: String { entry.id }
    var displayName: String { entry.displayName }
    var paidOnly: Bool { entry.paidOnly }
    var languages: [String] { caps.languages }
}

struct TranscriptionCaps: Decodable, Sendable {
    let languages: [String]
}
