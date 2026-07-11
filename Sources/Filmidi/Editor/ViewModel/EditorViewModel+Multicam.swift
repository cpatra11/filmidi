import AppKit

extension EditorViewModel {
    func createMulticamSource(name: String, colorRed: Double = 0.5, colorGreen: Double = 0.5, colorBlue: Double = 0.5) {
        let snapshot = multicamSnapshot()
        undoManager?.beginUndoGrouping()
        _ = multicamEngine.createSource(name: name, colorRed: colorRed, colorGreen: colorGreen, colorBlue: colorBlue)
        undoManager?.registerUndo(withTarget: self) { $0.restoreMulticamSnapshot(snapshot) }
        undoManager?.setActionName("Create Multicam Source")
        undoManager?.endUndoGrouping()
        syncMulticamToActiveTimeline()
        notifyTimelineChanged()
    }

    func removeMulticamSource(id: String) {
        let snapshot = multicamSnapshot()
        undoManager?.beginUndoGrouping()
        multicamEngine.removeSource(id: id)
        undoManager?.registerUndo(withTarget: self) { $0.restoreMulticamSnapshot(snapshot) }
        undoManager?.setActionName("Remove Multicam Source")
        undoManager?.endUndoGrouping()
        syncMulticamToActiveTimeline()
        notifyTimelineChanged()
    }

    func switchMulticamSource(to id: String?) {
        let snapshot = multicamSnapshot()
        undoManager?.beginUndoGrouping()
        multicamEngine.setActiveSource(id: id)
        undoManager?.registerUndo(withTarget: self) { $0.restoreMulticamSnapshot(snapshot) }
        undoManager?.setActionName(id != nil ? "Switch Multicam Source" : "Disable Multicam")
        undoManager?.endUndoGrouping()
        syncMulticamToActiveTimeline()
        notifyTimelineChanged()
    }

    func assignClipToSource(clipId: String, sourceId: String) {
        let snapshot = multicamSnapshot()
        undoManager?.beginUndoGrouping()
        multicamEngine.assignClip(clipId: clipId, to: sourceId)
        undoManager?.registerUndo(withTarget: self) { $0.restoreMulticamSnapshot(snapshot) }
        undoManager?.setActionName("Assign Clip to Source")
        undoManager?.endUndoGrouping()
        syncMulticamToActiveTimeline()
        notifyTimelineChanged()
    }

    func unassignClipFromSource(clipId: String) {
        let snapshot = multicamSnapshot()
        undoManager?.beginUndoGrouping()
        multicamEngine.unassignClip(clipId: clipId)
        undoManager?.registerUndo(withTarget: self) { $0.restoreMulticamSnapshot(snapshot) }
        undoManager?.setActionName("Unassign Clip from Source")
        undoManager?.endUndoGrouping()
        syncMulticamToActiveTimeline()
        notifyTimelineChanged()
    }

    // MARK: - Per-timeline persistence

    /// Syncs current engine state into the active Timeline's properties.
    func syncMulticamToActiveTimeline() {
        let i = timelines.firstIndex { $0.id == activeTimelineId }
        guard let i else { return }
        let s = multicamEngine.snapshot()
        timelines[i].multicamSources = s.sources
        timelines[i].multicamActiveSourceId = s.activeSourceId
        timelines[i].multicamAssignment = s.assignment
    }

    /// Restores engine state from a timeline's stored properties.
    func syncMulticamFromTimeline(_ tl: Timeline) {
        multicamEngine.restore(sources: tl.multicamSources,
                               activeSourceId: tl.multicamActiveSourceId,
                               assignment: tl.multicamAssignment)
    }

    // MARK: - Snapshot-based undo

    private struct MulticamSnapshot {
        let sources: [MulticamSource]
        let activeSourceId: String?
        let assignment: [String: String]
    }

    private func multicamSnapshot() -> MulticamSnapshot {
        let s = multicamEngine.snapshot()
        return MulticamSnapshot(sources: s.sources, activeSourceId: s.activeSourceId, assignment: s.assignment)
    }

    private func restoreMulticamSnapshot(_ snapshot: MulticamSnapshot) {
        multicamEngine.restore(sources: snapshot.sources, activeSourceId: snapshot.activeSourceId, assignment: snapshot.assignment)
        syncMulticamToActiveTimeline()
        notifyTimelineChanged()
    }
}
