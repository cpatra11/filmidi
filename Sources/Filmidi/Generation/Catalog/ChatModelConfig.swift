import Foundation

struct ChatModelConfig: Identifiable, Sendable {
    @MainActor
    static var allModels: [ChatModelConfig] { ModelCatalog.shared.chat }

    let entry: CatalogEntry
    let caps: ChatCaps

    var id: String { entry.id }
    var displayName: String { entry.displayName }
    var paidOnly: Bool { entry.paidOnly }
    var description: String { caps.description }
}

struct ChatCaps: Decodable, Sendable {
    let description: String
}
