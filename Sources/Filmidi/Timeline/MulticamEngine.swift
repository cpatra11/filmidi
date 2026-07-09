import Foundation

/// Tracks multicam sources and which clip IDs are assigned to each.
/// The engine does not own the timeline — it just maps clip IDs to sources.
@MainActor
final class MulticamEngine {
    var sources: [MulticamSource] = []
    var activeSourceId: String?

    /// clipId → sourceId
    private var assignment: [String: String] = [:]

    var activeSource: MulticamSource? {
        activeSourceId.flatMap { id in sources.first { $0.id == id } }
    }

    func createSource(name: String, colorRed: Double, colorGreen: Double, colorBlue: Double) -> MulticamSource {
        let source = MulticamSource(name: name, colorRed: colorRed, colorGreen: colorGreen, colorBlue: colorBlue)
        sources.append(source)
        return source
    }

    func removeSource(id: String) {
        sources.removeAll { $0.id == id }
        assignment = assignment.filter { $0.value != id }
        if activeSourceId == id { activeSourceId = sources.first?.id }
    }

    func renameSource(id: String, name: String) {
        guard let i = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[i].name = name
    }

    func setActiveSource(id: String?) {
        activeSourceId = id
    }

    func assignClip(clipId: String, to sourceId: String) {
        assignment[clipId] = sourceId
    }

    func unassignClip(clipId: String) {
        assignment.removeValue(forKey: clipId)
    }

    func clipSourceId(clipId: String) -> String? {
        assignment[clipId]
    }

    func clipsForSource(id: String) -> Set<String> {
        let ids = assignment.filter { $0.value == id }.map(\.key)
        return Set(ids)
    }

    /// When a source is active, only clips assigned to it (or unassigned clips) are visible.
    func isClipVisible(clipId: String) -> Bool {
        guard let active = activeSourceId else { return true }
        guard let assigned = assignment[clipId] else { return true }
        return assigned == active
    }

    var isActive: Bool { activeSourceId != nil }

    /// Filter tracks based on active source: hides clips that belong to non-active sources.
    func filteredTracks(_ tracks: [Track]) -> [Track] {
        guard let active = activeSourceId else { return tracks }
        return tracks.map { track in
            var t = track
            t.clips = t.clips.filter { clip in
                guard let assigned = assignment[clip.id] else { return true }
                return assigned == active
            }
            return t
        }
    }
}
