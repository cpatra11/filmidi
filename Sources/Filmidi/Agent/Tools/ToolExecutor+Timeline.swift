import AVFoundation
import Foundation
import ImageIO

extension ToolExecutor {
    private static let defaultReadVideoFrames = 6
    private static let readVideoMaxFrames = 12
    private nonisolated static let readVideoFrameMaxDimension: CGFloat = 512
    private nonisolated static let readVideoJPEGQuality: CGFloat = 0.7

    private static let getTimelineAllowedKeys: Set<String> = ["startFrame", "endFrame"]
    private static let captionRowLimit = 200
    private static let captionRowFormat = ["clipId", "startFrame", "durationFrames", "text"]

    func getTimeline(_ editor: EditorViewModel, _ args: [String: Any]) throws -> ToolResult {
        try validateUnknownKeys(args, allowed: Self.getTimelineAllowedKeys, path: "get_timeline")
        var window: Range<Int>?
        if args.int("startFrame") != nil || args.int("endFrame") != nil {
            let s = args.int("startFrame") ?? 0
            let e = args.int("endFrame") ?? Int.max
            guard s < e else {
                throw ToolError("Invalid window [\(s), \(e)): startFrame must be less than endFrame")
            }
            window = s..<e
        }

        guard var dict = try? JSONSerialization.jsonObject(
            with: JSONEncoder().encode(editor.timeline)
        ) as? [String: Any] else { throw ToolError("Failed to encode timeline") }

        // Apply multicam filtering so the agent only sees clips assigned to the active source.
        if editor.multicamEngine.isActive {
            let visible = editor.visibleTracks
            if let data = try? JSONEncoder().encode(visible),
               let encoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                dict["tracks"] = encoded
            }
        }

        if var tracks = dict["tracks"] as? [[String: Any]] {
            for i in tracks.indices {
                tracks[i] = Self.compactTrack(tracks[i], window: window)
                // Report the displayed label (mirrored video numbering), not the stored seed.
                tracks[i]["label"] = editor.timelineTrackDisplayLabel(at: i)
            }
            dict["tracks"] = tracks
        }
        dict["totalFrames"] = editor.timeline.totalFrames
        if let window {
            dict["window"] = [window.lowerBound, min(window.upperBound, editor.timeline.totalFrames)]
        }
        dict["currentFrame"] = editor.currentFrame
        dict["canGenerate"] = AccountService.shared.isSignedIn && AccountService.shared.hasCredits
        guard let json = Self.jsonString(roundJSONFloatingPointNumbers(dict, toPlaces: 3)) else {
            throw ToolError("Failed to encode timeline")
        }
        return .ok(json)
    }

    private static let trackDefaults: [String: Any] = ["muted": false, "hidden": false, "syncLocked": true]

    private static let clipDefaults: [String: Any] = {
        var clip = Clip(mediaRef: "", startFrame: 0, durationFrames: 0)
        clip.textStyle = TextStyle()
        guard let data = try? JSONEncoder().encode(clip),
              var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        // Identity fields stay; sourceClipType strips only when it matches mediaType.
        for key in ["id", "mediaRef", "startFrame", "durationFrames", "sourceClipType"] {
            obj.removeValue(forKey: key)
        }
        return obj
    }()

    private static func compactTrack(_ track: [String: Any], window: Range<Int>?) -> [String: Any] {
        var out = strippingDefaults(track, trackDefaults)
        guard let rawClips = track["clips"] as? [[String: Any]] else { return out }
        let compacted = rawClips.map { compactClip($0) }

        var loose: [[String: Any]] = []
        var groupOrder: [String] = []
        var grouped: [String: [[String: Any]]] = [:]
        for clip in compacted {
            if let gid = clip["captionGroupId"] as? String {
                if grouped[gid] == nil { groupOrder.append(gid) }
                grouped[gid, default: []].append(clip)
            } else {
                loose.append(clip)
            }
        }

        var groups: [[String: Any]] = []
        for gid in groupOrder {
            let (group, deviants) = captionGroup(gid: gid, members: grouped[gid] ?? [], window: window)
            groups.append(group)
            loose.append(contentsOf: deviants)
        }
        loose.sort { intValue($0["startFrame"]) < intValue($1["startFrame"]) }

        let visible = window.map { w in loose.filter { clipIntersects($0, w) } } ?? loose
        out["clips"] = visible
        if visible.count < loose.count { out["totalClips"] = loose.count }
        if !groups.isEmpty { out["captionGroups"] = groups }
        return out
    }

    private static func compactClip(_ clip: [String: Any]) -> [String: Any] {
        var out = compactClipKeyframes(clip)
        if let s = out["sourceClipType"] as? String, s == out["mediaType"] as? String {
            out.removeValue(forKey: "sourceClipType")
        }
        // Text has no source media; trims are placement bookkeeping, not signal.
        if out["mediaType"] as? String == "text" {
            out.removeValue(forKey: "trimStartFrame")
            out.removeValue(forKey: "trimEndFrame")
        }
        return strippingDefaults(out, clipDefaults)
    }

    /// Removes keys whose values equal the defaults; recurses into nested objects.
    private static func strippingDefaults(_ dict: [String: Any], _ defaults: [String: Any]) -> [String: Any] {
        var out = dict
        for (key, def) in defaults {
            guard let val = out[key] else { continue }
            if let v = val as? [String: Any], let d = def as? [String: Any] {
                let stripped = strippingDefaults(v, d)
                if stripped.isEmpty { out.removeValue(forKey: key) } else { out[key] = stripped }
            } else if (val as? NSObject)?.isEqual(def) == true {
                out.removeValue(forKey: key)
            }
        }
        return out
    }

    /// Collapses one caption group into shared properties + compact rows.
    private static func captionGroup(
        gid: String, members: [[String: Any]], window: Range<Int>?
    ) -> (group: [String: Any], deviants: [[String: Any]]) {
        let rowKeys: Set<String> = ["id", "startFrame", "durationFrames", "textContent", "captionGroupId"]
        var counts: [String: Int] = [:]
        var modalKey = ""
        var shared: [String: Any] = [:]
        let entries: [(clip: [String: Any], key: String)] = members.map { clip in
            var residual = clip.filter { !rowKeys.contains($0.key) }
            // Caption boxes are auto-fit per text; size is derived data, not signal.
            if var t = residual["transform"] as? [String: Any] {
                t.removeValue(forKey: "width")
                t.removeValue(forKey: "height")
                if t.isEmpty { residual.removeValue(forKey: "transform") } else { residual["transform"] = t }
            }
            let key = canonicalJSON(residual)
            counts[key, default: 0] += 1
            if counts[key]! > counts[modalKey, default: 0] {
                modalKey = key
                shared = residual
            }
            return (clip, key)
        }

        var rows: [[Any]] = []
        var deviants: [[String: Any]] = []
        var frameMin = Int.max
        var frameMax = 0
        for (clip, key) in entries {
            let start = intValue(clip["startFrame"])
            let end = start + intValue(clip["durationFrames"])
            frameMin = min(frameMin, start)
            frameMax = max(frameMax, end)
            if key == modalKey {
                rows.append([clip["id"] ?? "", start, end - start, clip["textContent"] ?? ""])
            } else {
                deviants.append(clip)
            }
        }

        let total = rows.count
        if let window {
            rows = rows.filter { intValue($0[1]) < window.upperBound && intValue($0[1]) + intValue($0[2]) > window.lowerBound }
        }
        rows.sort { intValue($0[1]) < intValue($1[1]) }
        let shown = Array(rows.prefix(captionRowLimit))

        var group: [String: Any] = [
            "captionGroupId": gid,
            "clipCount": total,
            "frameRange": [frameMin, frameMax],
            "clipFormat": captionRowFormat,
            "clips": shown,
        ]
        if !shared.isEmpty { group["shared"] = shared }
        if shown.count < total {
            group["clipsNote"] = "Showing \(shown.count) of \(total) caption clips. Page with startFrame/endFrame."
        }
        return (group, deviants)
    }

    private static func canonicalJSON(_ obj: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func clipIntersects(_ clip: [String: Any], _ window: Range<Int>) -> Bool {
        let start = intValue(clip["startFrame"])
        return start < window.upperBound && start + intValue(clip["durationFrames"]) > window.lowerBound
    }

    private static func intValue(_ v: Any?) -> Int { (v as? NSNumber)?.intValue ?? 0 }

    private static func compactClipKeyframes(_ clip: [String: Any]) -> [String: Any] {
        var out = clip
        var keyframes: [String: Any] = [:]
        for (trackKey, propKey, valueShape) in [
            ("volumeTrack", "volume", KeyframeValueShape.scalar),
            ("opacityTrack", "opacity", KeyframeValueShape.scalar),
            ("rotationTrack", "rotation", KeyframeValueShape.scalar),
            ("positionTrack", "position", KeyframeValueShape.pair),
            ("scaleTrack", "scale", KeyframeValueShape.pair),
            ("cropTrack", "crop", KeyframeValueShape.crop),
        ] {
            if let track = clip[trackKey] as? [String: Any],
               let kfs = track["keyframes"] as? [[String: Any]],
               !kfs.isEmpty {
                keyframes[propKey] = kfs.map { kf -> [Any] in
                    var row: [Any] = [kf["frame"] ?? 0]
                    row.append(contentsOf: valueShape.values(from: kf["value"]))
                    if let interp = kf["interpolationOut"] as? String, interp != "smooth" {
                        row.append(interp)
                    }
                    return row
                }
            }
            out.removeValue(forKey: trackKey)
        }
        if !keyframes.isEmpty { out["keyframes"] = keyframes }
        return out
    }

    private enum KeyframeValueShape {
        case scalar, pair, crop

        func values(from raw: Any?) -> [Any] {
            switch self {
            case .scalar:
                return [raw ?? 0]
            case .pair:
                guard let v = raw as? [String: Any] else { return [0, 0] }
                return [v["a"] ?? 0, v["b"] ?? 0]
            case .crop:
                guard let v = raw as? [String: Any] else { return [0, 0, 0, 0] }
                return [v["top"] ?? 0, v["right"] ?? 0, v["bottom"] ?? 0, v["left"] ?? 0]
            }
        }
    }

    static func compactTracks(_ tracks: [[String: Any]], editor: EditorViewModel, window: Range<Int>?, captionDetail: Bool) -> [[String: Any]] {
        tracks.enumerated().map { i, raw in
            var track = compactTrack(raw, window: window)
            track["index"] = i
            if !captionDetail {
                track.removeValue(forKey: "captionGroups")
                track.removeValue(forKey: "captionDetail")
            }
            return track
        }
    }

    func getMedia(_ editor: EditorViewModel) throws -> ToolResult {
        guard let obj = Self.encodeAsJSONObject(editor.mediaManifest),
              let json = Self.jsonString(roundJSONFloatingPointNumbers(obj, toPlaces: 3)) else {
            throw ToolError("Failed to encode media manifest")
        }
        return .ok(json)
    }
}
