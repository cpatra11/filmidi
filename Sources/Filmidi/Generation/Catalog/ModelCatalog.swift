import Foundation

enum ModelKind: Sendable {
    case video(VideoModelConfig)
    case image(ImageModelConfig)
    case audio(AudioModelConfig)
    case upscale(UpscaleModelConfig)
    case chat(ChatModelConfig)
    case transcription(TranscriptionModelConfig)
}

enum ModelRegistry {
    @MainActor static var byId: [String: ModelKind] { ModelCatalog.shared.byId }

    @MainActor static func exists(id: String) -> Bool { byId[id] != nil }


    @MainActor static func displayName(for id: String) -> String {
        switch byId[id] {
        case .video(let m): m.displayName
        case .image(let m): m.displayName
        case .audio(let m): m.displayName
        case .upscale(let m): m.displayName
        case .chat(let m): m.displayName
        case .transcription(let m): m.displayName
        case .none: id
        }
    }
}

@Observable
@MainActor
final class ModelCatalog {
    static let shared = ModelCatalog()

    private(set) var video: [VideoModelConfig] = []
    private(set) var image: [ImageModelConfig] = []
    private(set) var audio: [AudioModelConfig] = []
    private(set) var upscale: [UpscaleModelConfig] = []
    private(set) var chat: [ChatModelConfig] = []
    private(set) var transcription: [TranscriptionModelConfig] = []
    private(set) var byId: [String: ModelKind] = [:]
    private(set) var isLoaded: Bool = false
    private(set) var lastError: String?

    @ObservationIgnored private var didConfigure = false

    private init() {}

    func configure() {
        guard !didConfigure else { return }
        didConfigure = true
        loadDefaults()
    }

    private func loadDefaults() {
        let defaults: [CatalogEntry] = [
            // MARK: - Chat (Agent) models
            CatalogEntry(
                id: "qwen3.7-max", kind: .chat, displayName: "Qwen 3.7 Max",
                allowedEndpoints: ["anthropic-compat"], responseShape: .text,
                uiCapabilities: .chat(ChatCaps(description: "Highest intelligence, best reasoning, long context")),
                paidOnly: false
            ),
            CatalogEntry(
                id: "qwen3.7-plus", kind: .chat, displayName: "Qwen 3.7 Plus",
                allowedEndpoints: ["anthropic-compat"], responseShape: .text,
                uiCapabilities: .chat(ChatCaps(description: "Balanced intelligence and speed")),
                paidOnly: false
            ),
            CatalogEntry(
                id: "qwen3.6-plus", kind: .chat, displayName: "Qwen 3.6 Plus",
                allowedEndpoints: ["anthropic-compat"], responseShape: .text,
                uiCapabilities: .chat(ChatCaps(description: "Strong reasoning, faster than 3.7")),
                paidOnly: false
            ),
            CatalogEntry(
                id: "qwen3.6-flash", kind: .chat, displayName: "Qwen 3.6 Flash",
                allowedEndpoints: ["anthropic-compat"], responseShape: .text,
                uiCapabilities: .chat(ChatCaps(description: "Fast responses, economical")),
                paidOnly: false
            ),
            CatalogEntry(
                id: "qwen-turbo", kind: .chat, displayName: "Qwen Turbo",
                allowedEndpoints: ["anthropic-compat"], responseShape: .text,
                uiCapabilities: .chat(ChatCaps(description: "Most economical, fast")),
                paidOnly: false
            ),

            // MARK: - Image models
            CatalogEntry(
                id: "qwen-image-2.0-pro", kind: .image, displayName: "Qwen-Image 2.0 Pro",
                allowedEndpoints: ["multimodal-generation"], responseShape: .images,
                uiCapabilities: .image(ImageCaps(
                    resolutions: ["1024x1024", "1440x1440", "1920x1080"],
                    aspectRatios: ["16:9", "9:16", "1:1", "4:3", "3:2"],
                    qualities: ["standard", "hd"],
                    supportsImageReference: true, maxImages: 4
                )),
                qualities: ["standard", "hd"], paidOnly: false
            ),
            CatalogEntry(
                id: "qwen-image-2.0-turbo", kind: .image, displayName: "Qwen-Image 2.0 Turbo",
                allowedEndpoints: ["multimodal-generation"], responseShape: .images,
                uiCapabilities: .image(ImageCaps(
                    resolutions: ["1024x1024"],
                    aspectRatios: ["16:9", "9:16", "1:1", "4:3", "3:2"],
                    qualities: ["standard"],
                    supportsImageReference: false, maxImages: 1
                )),
                qualities: ["standard"], paidOnly: false
            ),
            CatalogEntry(
                id: "wan2.7-image-pro", kind: .image, displayName: "Wan 2.7 Image Pro",
                allowedEndpoints: ["wanx-image-generation"], responseShape: .images,
                uiCapabilities: .image(ImageCaps(
                    resolutions: ["1024x1024", "1440x1440"],
                    aspectRatios: ["16:9", "9:16", "1:1", "4:3", "3:2"],
                    qualities: ["standard", "hd"],
                    supportsImageReference: true, maxImages: 4
                )),
                qualities: ["standard", "hd"], paidOnly: false
            ),
            CatalogEntry(
                id: "wan2.6-t2i", kind: .image, displayName: "Wan 2.6 Text-to-Image",
                allowedEndpoints: ["multimodal-generation"], responseShape: .images,
                uiCapabilities: .image(ImageCaps(
                    resolutions: ["1024x1024"],
                    aspectRatios: ["16:9", "9:16", "1:1", "4:3", "3:2"],
                    qualities: ["standard"],
                    supportsImageReference: false, maxImages: 1
                )),
                qualities: ["standard"], paidOnly: false
            ),

            // MARK: - Video models
            CatalogEntry(
                id: "wan2.7-t2v", kind: .video, displayName: "Wan 2.7 Text-to-Video",
                allowedEndpoints: ["video-synthesis"], responseShape: .video,
                uiCapabilities: .video(VideoCaps(
                    durations: [5, 10, 15, 20], resolutions: ["720p", "1080p"],
                    aspectRatios: ["16:9", "9:16", "1:1"],
                    supportsFirstFrame: false, supportsLastFrame: false,
                    maxReferenceImages: 0, maxReferenceVideos: 0, maxReferenceAudios: 0,
                    maxTotalReferences: nil, maxCombinedVideoRefSeconds: nil,
                    maxCombinedAudioRefSeconds: nil, framesAndReferencesExclusive: false,
                    referenceTagNoun: "reference", requiresSourceVideo: false,
                    requiresReferenceImage: false
                )),
                paidOnly: false
            ),
            CatalogEntry(
                id: "wan2.7-i2v", kind: .video, displayName: "Wan 2.7 Image-to-Video",
                allowedEndpoints: ["video-synthesis"], responseShape: .video,
                uiCapabilities: .video(VideoCaps(
                    durations: [5, 10, 15, 20], resolutions: ["720p", "1080p"],
                    aspectRatios: ["16:9", "9:16", "1:1"],
                    supportsFirstFrame: true, supportsLastFrame: false,
                    maxReferenceImages: 0, maxReferenceVideos: 0, maxReferenceAudios: 0,
                    maxTotalReferences: nil, maxCombinedVideoRefSeconds: nil,
                    maxCombinedAudioRefSeconds: nil, framesAndReferencesExclusive: false,
                    referenceTagNoun: "reference", requiresSourceVideo: false,
                    requiresReferenceImage: false
                )),
                paidOnly: false
            ),
            CatalogEntry(
                id: "wan2.7-r2v", kind: .video, displayName: "Wan 2.7 Reference-to-Video",
                allowedEndpoints: ["video-synthesis"], responseShape: .video,
                uiCapabilities: .video(VideoCaps(
                    durations: [5, 10, 15, 20], resolutions: ["720p", "1080p"],
                    aspectRatios: ["16:9", "9:16", "1:1"],
                    supportsFirstFrame: false, supportsLastFrame: false,
                    maxReferenceImages: 0, maxReferenceVideos: 1, maxReferenceAudios: 0,
                    maxTotalReferences: 1, maxCombinedVideoRefSeconds: nil,
                    maxCombinedAudioRefSeconds: nil, framesAndReferencesExclusive: false,
                    referenceTagNoun: "reference video", requiresSourceVideo: false,
                    requiresReferenceImage: false
                )),
                paidOnly: false
            ),
            CatalogEntry(
                id: "wan2.7-videoedit", kind: .video, displayName: "Wan 2.7 Video Editing",
                allowedEndpoints: ["video-synthesis"], responseShape: .video,
                uiCapabilities: .video(VideoCaps(
                    durations: [5, 10, 15, 20], resolutions: ["720p", "1080p"],
                    aspectRatios: ["16:9", "9:16", "1:1"],
                    supportsFirstFrame: false, supportsLastFrame: false,
                    maxReferenceImages: 0, maxReferenceVideos: 0, maxReferenceAudios: 0,
                    maxTotalReferences: nil, maxCombinedVideoRefSeconds: nil,
                    maxCombinedAudioRefSeconds: nil, framesAndReferencesExclusive: false,
                    referenceTagNoun: "reference", requiresSourceVideo: true,
                    requiresReferenceImage: false
                )),
                paidOnly: false
            ),
            CatalogEntry(
                id: "happyhorse-1.1-t2v", kind: .video, displayName: "HappyHorse 1.1 Text-to-Video",
                allowedEndpoints: ["happyhorse-text-to-video"], responseShape: .video,
                uiCapabilities: .video(VideoCaps(
                    durations: [5, 10, 15], resolutions: ["720p", "1080p"],
                    aspectRatios: ["16:9", "9:16", "1:1"],
                    supportsFirstFrame: false, supportsLastFrame: false,
                    maxReferenceImages: 0, maxReferenceVideos: 0, maxReferenceAudios: 0,
                    maxTotalReferences: nil, maxCombinedVideoRefSeconds: nil,
                    maxCombinedAudioRefSeconds: nil, framesAndReferencesExclusive: false,
                    referenceTagNoun: "reference", requiresSourceVideo: false,
                    requiresReferenceImage: false
                )),
                paidOnly: false
            ),
            CatalogEntry(
                id: "happyhorse-1.1-i2v", kind: .video, displayName: "HappyHorse 1.1 Image-to-Video",
                allowedEndpoints: ["happyhorse-image-to-video"], responseShape: .video,
                uiCapabilities: .video(VideoCaps(
                    durations: [5, 10, 15], resolutions: ["720p", "1080p"],
                    aspectRatios: ["16:9", "9:16", "1:1"],
                    supportsFirstFrame: true, supportsLastFrame: false,
                    maxReferenceImages: 0, maxReferenceVideos: 0, maxReferenceAudios: 0,
                    maxTotalReferences: nil, maxCombinedVideoRefSeconds: nil,
                    maxCombinedAudioRefSeconds: nil, framesAndReferencesExclusive: false,
                    referenceTagNoun: "reference", requiresSourceVideo: false,
                    requiresReferenceImage: false
                )),
                paidOnly: false
            ),
            CatalogEntry(
                id: "happyhorse-1.1-r2v", kind: .video, displayName: "HappyHorse 1.1 Reference-to-Video",
                allowedEndpoints: ["happyhorse-reference-to-video"], responseShape: .video,
                uiCapabilities: .video(VideoCaps(
                    durations: [5, 10, 15], resolutions: ["720p", "1080p"],
                    aspectRatios: ["16:9", "9:16", "1:1"],
                    supportsFirstFrame: false, supportsLastFrame: false,
                    maxReferenceImages: 0, maxReferenceVideos: 1, maxReferenceAudios: 0,
                    maxTotalReferences: 1, maxCombinedVideoRefSeconds: nil,
                    maxCombinedAudioRefSeconds: nil, framesAndReferencesExclusive: false,
                    referenceTagNoun: "reference video", requiresSourceVideo: false,
                    requiresReferenceImage: false
                )),
                paidOnly: false
            ),

            // MARK: - Audio / TTS models
            CatalogEntry(
                id: "qwen3-tts-flash", kind: .audio, displayName: "Qwen3 TTS Flash",
                allowedEndpoints: ["multimodal-generation"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "tts",
                    voices: ["default-female", "default-male", "gentle-female", "deep-male"],
                    defaultVoice: "default-female", supportsLyrics: false,
                    supportsInstrumental: false, supportsStyleInstructions: true,
                    durations: nil, minPromptLength: 1,
                    inputs: ["text"], promptLabel: nil, minSeconds: nil, maxSeconds: nil
                )),
                audioPricing: .perSecond(rate: 5), paidOnly: false
            ),
            CatalogEntry(
                id: "qwen3-tts-instruct-flash", kind: .audio, displayName: "Qwen3 TTS Instruct Flash",
                allowedEndpoints: ["multimodal-generation"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "tts",
                    voices: ["default-female", "default-male", "gentle-female", "deep-male", "narrative-female", "narrative-male"],
                    defaultVoice: "default-female", supportsLyrics: false,
                    supportsInstrumental: false, supportsStyleInstructions: true,
                    durations: nil, minPromptLength: 1,
                    inputs: ["text"], promptLabel: nil, minSeconds: nil, maxSeconds: nil
                )),
                audioPricing: .perSecond(rate: 5), paidOnly: false
            ),
            CatalogEntry(
                id: "cosyvoice-v3-plus", kind: .audio, displayName: "CosyVoice v3 Plus",
                allowedEndpoints: ["multimodal-generation"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "tts",
                    voices: ["cosy-female", "cosy-male", "cosy-narrative", "cosy-news"],
                    defaultVoice: "cosy-female", supportsLyrics: false,
                    supportsInstrumental: false, supportsStyleInstructions: true,
                    durations: nil, minPromptLength: 1,
                    inputs: ["text"], promptLabel: nil, minSeconds: nil, maxSeconds: nil
                )),
                audioPricing: .perSecond(rate: 8), paidOnly: false
            ),
            CatalogEntry(
                id: "cosyvoice-v3-flash", kind: .audio, displayName: "CosyVoice v3 Flash",
                allowedEndpoints: ["multimodal-generation"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "tts",
                    voices: ["cosy-female", "cosy-male", "cosy-narrative", "cosy-news"],
                    defaultVoice: "cosy-female", supportsLyrics: false,
                    supportsInstrumental: false, supportsStyleInstructions: true,
                    durations: nil, minPromptLength: 1,
                    inputs: ["text"], promptLabel: nil, minSeconds: nil, maxSeconds: nil
                )),
                audioPricing: .perSecond(rate: 3), paidOnly: false
            ),

            // MARK: - Music / SFX models
            CatalogEntry(
                id: "fun-music-v1", kind: .audio, displayName: "FunMusic v1",
                allowedEndpoints: ["multimodal-generation"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "music",
                    voices: nil, defaultVoice: nil,
                    supportsLyrics: true, supportsInstrumental: true,
                    supportsStyleInstructions: false,
                    durations: nil, minPromptLength: 1,
                    inputs: ["text"], promptLabel: "Describe the music", minSeconds: nil, maxSeconds: nil
                )),
                audioPricing: .perSecond(rate: 25), paidOnly: false
            ),
            CatalogEntry(
                id: "fun-music-preview", kind: .audio, displayName: "FunMusic Preview",
                allowedEndpoints: ["multimodal-generation"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "music",
                    voices: nil, defaultVoice: nil,
                    supportsLyrics: true, supportsInstrumental: false,
                    supportsStyleInstructions: false,
                    durations: nil, minPromptLength: 1,
                    inputs: ["text"], promptLabel: "Describe the music", minSeconds: nil, maxSeconds: nil
                )),
                audioPricing: .perSecond(rate: 10), paidOnly: false
            ),
            CatalogEntry(
                id: "sonilo-v1.1-video-to-music", kind: .audio, displayName: "Sonilo Video to Music v1.1",
                allowedEndpoints: ["sonilo"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "music",
                    voices: nil, defaultVoice: nil,
                    supportsLyrics: false, supportsInstrumental: false,
                    supportsStyleInstructions: false, supportsSegments: true,
                    durations: nil, minPromptLength: 1,
                    inputs: ["video"], promptLabel: nil, minSeconds: 5, maxSeconds: 360
                )),
                audioPricing: .perSecond(rate: 30), paidOnly: false
            ),
            CatalogEntry(
                id: "sonilo-v1.1-text-to-music", kind: .audio, displayName: "Sonilo Text to Music v1.1",
                allowedEndpoints: ["sonilo"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "music",
                    voices: nil, defaultVoice: nil,
                    supportsLyrics: false, supportsInstrumental: true,
                    supportsStyleInstructions: false, supportsSegments: true,
                    durations: nil, minPromptLength: 1,
                    inputs: ["text"], promptLabel: "Describe the music", minSeconds: 5, maxSeconds: 360
                )),
                audioPricing: .perSecond(rate: 30), paidOnly: false
            ),
            CatalogEntry(
                id: "mirelo-sfx-v1.5-video-to-audio", kind: .audio, displayName: "Mirelo SFX v1.5",
                allowedEndpoints: ["mirelo"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "sfx",
                    voices: nil, defaultVoice: nil,
                    supportsLyrics: false, supportsInstrumental: false,
                    supportsStyleInstructions: false,
                    durations: nil, minPromptLength: 1,
                    inputs: ["video"], promptLabel: "Describe the sound", minSeconds: nil, maxSeconds: nil
                )),
                audioPricing: .perSecond(rate: 20), paidOnly: false
            ),
            CatalogEntry(
                id: "mirelo-sfx-v1.5-text-to-sfx", kind: .audio, displayName: "Mirelo Text to SFX v1.5",
                allowedEndpoints: ["mirelo"], responseShape: .audio,
                uiCapabilities: .audio(AudioCaps(
                    category: "sfx",
                    voices: nil, defaultVoice: nil,
                    supportsLyrics: false, supportsInstrumental: false,
                    supportsStyleInstructions: false,
                    durations: nil, minPromptLength: 1,
                    inputs: ["text"], promptLabel: "Describe the sound", minSeconds: nil, maxSeconds: nil
                )),
                audioPricing: .perSecond(rate: 20), paidOnly: false
            ),

            // MARK: - Speech-to-Text / Transcription models
            CatalogEntry(
                id: "paraformer-realtime-v2", kind: .transcription, displayName: "Paraformer Real-time v2",
                allowedEndpoints: ["asr-task"], responseShape: .transcriptionData,
                uiCapabilities: .transcription(TranscriptionCaps(
                    languages: ["zh", "en", "ja", "ko", "fr", "de", "es", "pt", "it", "ru", "ar", "vi", "th"]
                )),
                paidOnly: false
            ),
            CatalogEntry(
                id: "fun-asr-realtime", kind: .transcription, displayName: "Fun ASR Real-time",
                allowedEndpoints: ["asr-task"], responseShape: .transcriptionData,
                uiCapabilities: .transcription(TranscriptionCaps(
                    languages: ["zh", "en", "ja", "ko"]
                )),
                paidOnly: false
            ),
            CatalogEntry(
                id: "qwen3-asr-flash-realtime", kind: .transcription, displayName: "Qwen3 ASR Flash Real-time",
                allowedEndpoints: ["asr-task"], responseShape: .transcriptionData,
                uiCapabilities: .transcription(TranscriptionCaps(
                    languages: ["zh", "en", "ja", "ko", "fr", "de", "es"]
                )),
                paidOnly: false
            ),
            CatalogEntry(
                id: "fun-asr", kind: .transcription, displayName: "Fun ASR",
                allowedEndpoints: ["asr-task"], responseShape: .transcriptionData,
                uiCapabilities: .transcription(TranscriptionCaps(
                    languages: ["zh", "en", "ja", "ko"]
                )),
                paidOnly: false
            ),
        ]
        apply(defaults)
    }

    private func apply(_ entries: [CatalogEntry]) {
        var newVideo: [VideoModelConfig] = []
        var newImage: [ImageModelConfig] = []
        var newAudio: [AudioModelConfig] = []
        var newUpscale: [UpscaleModelConfig] = []
        var newChat: [ChatModelConfig] = []
        var newTranscription: [TranscriptionModelConfig] = []
        var newById: [String: ModelKind] = [:]
        newVideo.reserveCapacity(entries.count)
        newImage.reserveCapacity(entries.count)
        newAudio.reserveCapacity(entries.count)
        newUpscale.reserveCapacity(entries.count)
        newChat.reserveCapacity(entries.count)
        newTranscription.reserveCapacity(entries.count)
        newById.reserveCapacity(entries.count)

        for entry in entries {
            switch entry.uiCapabilities {
            case .video(let caps):
                let m = VideoModelConfig(entry: entry, caps: caps)
                newVideo.append(m)
                newById[m.id] = .video(m)
            case .image(let caps):
                let m = ImageModelConfig(entry: entry, caps: caps)
                newImage.append(m)
                newById[m.id] = .image(m)
            case .audio(let caps):
                let m = AudioModelConfig(entry: entry, caps: caps)
                newAudio.append(m)
                newById[m.id] = .audio(m)
            case .upscale(let caps):
                let m = UpscaleModelConfig(entry: entry, caps: caps)
                newUpscale.append(m)
                newById[m.id] = .upscale(m)
            case .chat(let caps):
                let m = ChatModelConfig(entry: entry, caps: caps)
                newChat.append(m)
                newById[m.id] = .chat(m)
            case .transcription(let caps):
                let m = TranscriptionModelConfig(entry: entry, caps: caps)
                newTranscription.append(m)
                newById[m.id] = .transcription(m)
            }
        }

        self.video = newVideo
        self.image = newImage
        self.audio = newAudio
        self.upscale = newUpscale
        self.chat = newChat
        self.transcription = newTranscription
        self.byId = newById
        self.isLoaded = true
        self.lastError = nil
    }
}

struct CatalogEntry: Decodable, Sendable {
    let id: String
    let kind: Kind
    let displayName: String
    let allowedEndpoints: [String]
    let responseShape: ResponseShape
    let uiCapabilities: UICapabilities
    let creditsPerSecond: [String: Double]?
    let audioDiscountRate: [String: Double]?
    let creditsPerImage: [String: Double]?
    let qualities: [String]?
    let audioPricing: AudioPricing?
    let creditsPerSecondUpscale: Double?
    let paidOnly: Bool

    init(
        id: String, kind: Kind, displayName: String,
        allowedEndpoints: [String], responseShape: ResponseShape,
        uiCapabilities: UICapabilities,
        creditsPerSecond: [String: Double]? = nil,
        audioDiscountRate: [String: Double]? = nil,
        creditsPerImage: [String: Double]? = nil,
        qualities: [String]? = nil,
        audioPricing: AudioPricing? = nil,
        creditsPerSecondUpscale: Double? = nil,
        paidOnly: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.allowedEndpoints = allowedEndpoints
        self.responseShape = responseShape
        self.uiCapabilities = uiCapabilities
        self.creditsPerSecond = creditsPerSecond
        self.audioDiscountRate = audioDiscountRate
        self.creditsPerImage = creditsPerImage
        self.qualities = qualities
        self.audioPricing = audioPricing
        self.creditsPerSecondUpscale = creditsPerSecondUpscale
        self.paidOnly = paidOnly
    }

    enum Kind: String, Decodable, Sendable { case video, image, audio, upscale, chat, transcription }
    enum ResponseShape: String, Decodable, Sendable {
        case video, images, audio, upscaledImage, text, transcriptionData
    }

    enum UICapabilities: Sendable {
        case video(VideoCaps)
        case image(ImageCaps)
        case audio(AudioCaps)
        case upscale(UpscaleCaps)
        case chat(ChatCaps)
        case transcription(TranscriptionCaps)
    }

    enum AudioPricing: Decodable, Sendable {
        case perThousandChars(rate: Double)
        case perSecond(rate: Double)
        case flat(price: Double)

        private enum K: String, CodingKey { case mode, rate, price }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: K.self)
            switch try c.decode(String.self, forKey: .mode) {
            case "perThousandChars":
                self = .perThousandChars(rate: try c.decode(Double.self, forKey: .rate))
            case "perSecond":
                self = .perSecond(rate: try c.decode(Double.self, forKey: .rate))
            case "flat":
                self = .flat(price: try c.decode(Double.self, forKey: .price))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .mode, in: c,
                    debugDescription: "Unknown audio pricing mode"
                )
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, displayName, allowedEndpoints, responseShape, uiCapabilities
        case creditsPerSecond, audioDiscountRate, creditsPerImage, qualities
        case audioPricing, creditsPerSecondUpscale, paidOnly
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.kind = try c.decode(Kind.self, forKey: .kind)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.allowedEndpoints = try c.decode([String].self, forKey: .allowedEndpoints)
        self.responseShape = try c.decode(ResponseShape.self, forKey: .responseShape)
        self.creditsPerSecond = try c.decodeIfPresent([String: Double].self, forKey: .creditsPerSecond)
        self.audioDiscountRate = try c.decodeIfPresent([String: Double].self, forKey: .audioDiscountRate)
        self.creditsPerImage = try c.decodeIfPresent([String: Double].self, forKey: .creditsPerImage)
        self.qualities = try c.decodeIfPresent([String].self, forKey: .qualities)
        self.audioPricing = try c.decodeIfPresent(AudioPricing.self, forKey: .audioPricing)
        self.creditsPerSecondUpscale = try c.decodeIfPresent(Double.self, forKey: .creditsPerSecondUpscale)
        self.paidOnly = try c.decodeIfPresent(Bool.self, forKey: .paidOnly) ?? false
        switch self.kind {
        case .video:
            self.uiCapabilities = .video(try c.decode(VideoCaps.self, forKey: .uiCapabilities))
        case .image:
            self.uiCapabilities = .image(try c.decode(ImageCaps.self, forKey: .uiCapabilities))
        case .audio:
            self.uiCapabilities = .audio(try c.decode(AudioCaps.self, forKey: .uiCapabilities))
        case .upscale:
            self.uiCapabilities = .upscale(try c.decode(UpscaleCaps.self, forKey: .uiCapabilities))
        case .chat:
            self.uiCapabilities = .chat(try c.decode(ChatCaps.self, forKey: .uiCapabilities))
        case .transcription:
            self.uiCapabilities = .transcription(try c.decode(TranscriptionCaps.self, forKey: .uiCapabilities))
        }
    }
}

struct VideoCaps: Decodable, Sendable {
    let durations: [Int]
    let resolutions: [String]?
    let aspectRatios: [String]
    let supportsFirstFrame: Bool
    let supportsLastFrame: Bool
    let maxReferenceImages: Int
    let maxReferenceVideos: Int
    let maxReferenceAudios: Int
    let maxTotalReferences: Int?
    let maxCombinedVideoRefSeconds: Double?
    let maxCombinedAudioRefSeconds: Double?
    let framesAndReferencesExclusive: Bool
    let referenceTagNoun: String
    let requiresSourceVideo: Bool
    let requiresReferenceImage: Bool
}

struct ImageCaps: Decodable, Sendable {
    let resolutions: [String]?
    let aspectRatios: [String]
    let qualities: [String]?
    let supportsImageReference: Bool
    let maxImages: Int
}

struct AudioCaps: Decodable, Sendable {
    let category: String   // "tts" | "music" | "sfx"
    let voices: [String]?
    let defaultVoice: String?
    let supportsLyrics: Bool
    let supportsInstrumental: Bool
    let supportsStyleInstructions: Bool
    var supportsSegments: Bool? = nil
    let durations: [Int]?
    let minPromptLength: Int
    let inputs: [String]? // "text" | "video"
    let promptLabel: String?
    let minSeconds: Int?
    let maxSeconds: Int?
}

struct UpscaleCaps: Decodable, Sendable {
    let speed: String   // "Fast" | "Medium" | "Slow"
    let p75DurationSeconds: Int
    let supportedTypes: [String]   // "video" | "image"
}
