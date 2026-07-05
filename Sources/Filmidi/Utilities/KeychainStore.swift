import Foundation

private let kStoreFile = "io.filmidi.credentials.json"

private func storeURL() -> URL? {
    try? FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    ).appendingPathComponent(kStoreFile)
}

private func readAll() -> [String: String] {
    guard let url = storeURL(),
          let data = try? Data(contentsOf: url),
          let dict = try? JSONDecoder().decode([String: String].self, from: data)
    else { return [:] }
    return dict
}

private func writeAll(_ dict: [String: String]) {
    guard let url = storeURL() else { return }
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    if let data = try? JSONEncoder().encode(dict) {
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

enum KeychainStore {
    static func save(_ value: String, account: String) {
        var dict = readAll()
        dict[account] = value
        writeAll(dict)
    }

    static func load(account: String) -> String? {
        readAll()[account]
    }

    static func delete(account: String) {
        var dict = readAll()
        dict.removeValue(forKey: account)
        writeAll(dict)
    }
}
