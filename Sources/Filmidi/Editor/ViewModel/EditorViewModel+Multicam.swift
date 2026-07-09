import AppKit

extension EditorViewModel {
    func createMulticamSource(name: String, colorRed: Double = 0.5, colorGreen: Double = 0.5, colorBlue: Double = 0.5) {
        multicamEngine.createSource(name: name, colorRed: colorRed, colorGreen: colorGreen, colorBlue: colorBlue)
        notifyTimelineChanged()
    }

    func removeMulticamSource(id: String) {
        multicamEngine.removeSource(id: id)
        notifyTimelineChanged()
    }

    func switchMulticamSource(to id: String?) {
        multicamEngine.setActiveSource(id: id)
        notifyTimelineChanged()
    }

    func assignClipToSource(clipId: String, sourceId: String) {
        multicamEngine.assignClip(clipId: clipId, to: sourceId)
        notifyTimelineChanged()
    }

    func unassignClipFromSource(clipId: String) {
        multicamEngine.unassignClip(clipId: clipId)
        notifyTimelineChanged()
    }
}
