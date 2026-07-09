import Foundation

struct MulticamSource: Codable, Sendable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var colorRed: Double = 0.5
    var colorGreen: Double = 0.5
    var colorBlue: Double = 0.5
    var isMuted: Bool = false
}
