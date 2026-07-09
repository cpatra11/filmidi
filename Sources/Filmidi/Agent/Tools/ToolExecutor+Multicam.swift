import Foundation

extension ToolExecutor {
    func listMulticamSources(_ editor: EditorViewModel) -> ToolResult {
        let engine = editor.multicamEngine
        guard !engine.sources.isEmpty else {
            return .ok("No multicam sources configured.")
        }
        var lines: [String] = []
        for s in engine.sources {
            let active = s.id == engine.activeSourceId ? " [active]" : ""
            let count = engine.clipsForSource(id: s.id).count
            lines.append("• \(s.name) (\(count) clips)\(active)")
        }
        return .ok(lines.joined(separator: "\n"))
    }

    func switchMulticamSource(_ editor: EditorViewModel, args: [String: Any]) throws -> ToolResult {
        if let sourceId = args.string("sourceId") {
            guard editor.multicamEngine.sources.contains(where: { $0.id == sourceId }) else {
                throw ToolError("Multicam source not found: \(sourceId)")
            }
            editor.switchMulticamSource(to: sourceId)
            return .ok("Switched to source '\(sourceId)'.")
        }
        editor.switchMulticamSource(to: nil)
        return .ok("Multicam disabled — all sources visible.")
    }

    func addMulticamSource(_ editor: EditorViewModel, args: [String: Any]) throws -> ToolResult {
        let name = try args.requireString("name")
        editor.createMulticamSource(name: name)
        return .ok("Created multicam source '\(name)'.")
    }

    func removeMulticamSource(_ editor: EditorViewModel, args: [String: Any]) throws -> ToolResult {
        let sourceId = try args.requireString("sourceId")
        editor.removeMulticamSource(id: sourceId)
        return .ok("Removed multicam source \(sourceId).")
    }

    func renameMulticamSource(_ editor: EditorViewModel, args: [String: Any]) throws -> ToolResult {
        let sourceId = try args.requireString("sourceId")
        let name = try args.requireString("name")
        editor.multicamEngine.renameSource(id: sourceId, name: name)
        return .ok("Renamed source to '\(name)'.")
    }

    func assignClipToSource(_ editor: EditorViewModel, args: [String: Any]) throws -> ToolResult {
        let clipId = try args.requireString("clipId")
        let sourceId = try args.requireString("sourceId")
        guard editor.multicamEngine.sources.contains(where: { $0.id == sourceId }) else {
            throw ToolError("Multicam source not found: \(sourceId)")
        }
        editor.assignClipToSource(clipId: clipId, sourceId: sourceId)
        return .ok("Assigned clip \(clipId) to source \(sourceId).")
    }
}
