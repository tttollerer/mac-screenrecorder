import Foundation

final class RecorderSettings: ObservableObject {
    @Published var selectedPreset: RecordingPreset {
        didSet { defaults.set(selectedPreset.rawValue, forKey: Keys.selectedPreset) }
    }

    @Published var exportDestination: ExportDestination {
        didSet { defaults.set(exportDestination.rawValue, forKey: Keys.exportDestination) }
    }

    @Published var includeMicrophone: Bool {
        didSet { defaults.set(includeMicrophone, forKey: Keys.includeMicrophone) }
    }

    @Published var includeSystemAudio: Bool {
        didSet { defaults.set(includeSystemAudio, forKey: Keys.includeSystemAudio) }
    }

    @Published var showCursor: Bool {
        didSet { defaults.set(showCursor, forKey: Keys.showCursor) }
    }

    @Published var highlightClicks: Bool {
        didSet { defaults.set(highlightClicks, forKey: Keys.highlightClicks) }
    }

    @Published var countdownEnabled: Bool {
        didSet { defaults.set(countdownEnabled, forKey: Keys.countdownEnabled) }
    }

    @Published var selectedMicrophoneID: String {
        didSet { defaults.set(selectedMicrophoneID, forKey: Keys.selectedMicrophoneID) }
    }

    @Published var outputFolderPath: String {
        didSet { defaults.set(outputFolderPath, forKey: Keys.outputFolderPath) }
    }

    @Published var videoResolution: VideoResolution {
        didSet { defaults.set(videoResolution.rawValue, forKey: Keys.videoResolution) }
    }

    @Published var videoQuality: VideoQuality {
        didSet { defaults.set(videoQuality.rawValue, forKey: Keys.videoQuality) }
    }

    @Published var videoCodec: VideoCodec {
        didSet { defaults.set(videoCodec.rawValue, forKey: Keys.videoCodec) }
    }

    @Published var frameRate: FrameRate {
        didSet { defaults.set(frameRate.rawValue, forKey: Keys.frameRate) }
    }

    @Published var customBitrateMbps: Int {
        didSet { defaults.set(customBitrateMbps, forKey: Keys.customBitrateMbps) }
    }

    @Published var clickHighlightColor: ClickHighlightColor {
        didSet { defaults.set(clickHighlightColor.rawValue, forKey: Keys.clickHighlightColor) }
    }

    @Published var clickHighlightSize: ClickHighlightSize {
        didSet { defaults.set(clickHighlightSize.rawValue, forKey: Keys.clickHighlightSize) }
    }

    @Published var hideAppDuringRecording: Bool {
        didSet { defaults.set(hideAppDuringRecording, forKey: Keys.hideAppDuringRecording) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedPreset = defaults.string(forKey: Keys.selectedPreset)
        selectedPreset = storedPreset.flatMap(RecordingPreset.init(rawValue:)) ?? .retinaSharp
        let storedExportDestination = defaults.string(forKey: Keys.exportDestination)
        exportDestination = storedExportDestination.flatMap(ExportDestination.init(rawValue:)) ?? .youtube
        includeMicrophone = defaults.object(forKey: Keys.includeMicrophone) as? Bool ?? true
        includeSystemAudio = defaults.object(forKey: Keys.includeSystemAudio) as? Bool ?? true
        showCursor = defaults.object(forKey: Keys.showCursor) as? Bool ?? true
        highlightClicks = defaults.object(forKey: Keys.highlightClicks) as? Bool ?? true
        countdownEnabled = defaults.object(forKey: Keys.countdownEnabled) as? Bool ?? true
        selectedMicrophoneID = defaults.string(forKey: Keys.selectedMicrophoneID) ?? ""
        outputFolderPath = defaults.string(forKey: Keys.outputFolderPath)
            ?? FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first?.path
            ?? NSHomeDirectory()
        let storedResolution = defaults.string(forKey: Keys.videoResolution)
        videoResolution = storedResolution.flatMap(VideoResolution.init(rawValue:)) ?? .native
        let storedQuality = defaults.string(forKey: Keys.videoQuality)
        videoQuality = storedQuality.flatMap(VideoQuality.init(rawValue:)) ?? .high
        let storedCodec = defaults.string(forKey: Keys.videoCodec)
        videoCodec = storedCodec.flatMap(VideoCodec.init(rawValue:)) ?? .h264
        let storedFrameRate = defaults.object(forKey: Keys.frameRate) as? Int
        frameRate = storedFrameRate.flatMap(FrameRate.init(rawValue:)) ?? .fps30
        customBitrateMbps = defaults.object(forKey: Keys.customBitrateMbps) as? Int ?? 0
        let storedClickColor = defaults.string(forKey: Keys.clickHighlightColor)
        clickHighlightColor = storedClickColor.flatMap(ClickHighlightColor.init(rawValue:)) ?? .blue
        let storedClickSize = defaults.string(forKey: Keys.clickHighlightSize)
        clickHighlightSize = storedClickSize.flatMap(ClickHighlightSize.init(rawValue:)) ?? .normal
        hideAppDuringRecording = defaults.object(forKey: Keys.hideAppDuringRecording) as? Bool ?? true
    }

    func apply(_ preset: RecordingPreset) {
        selectedPreset = preset

        switch preset {
        case .webDemo1080p:
            videoResolution = .fullHD
            videoQuality = .high
            videoCodec = .h264
            frameRate = .fps30
            customBitrateMbps = 24
            showCursor = true
            highlightClicks = true
        case .retinaSharp:
            videoResolution = .native
            videoQuality = .losslessLike
            videoCodec = .h264
            frameRate = .fps60
            customBitrateMbps = 80
            showCursor = true
            highlightClicks = true
        case .socialClip:
            videoResolution = .fullHD
            videoQuality = .high
            videoCodec = .h264
            frameRate = .fps30
            customBitrateMbps = 18
            showCursor = true
            highlightClicks = true
        case .browserWindow:
            videoResolution = .quadHD
            videoQuality = .losslessLike
            videoCodec = .h264
            frameRate = .fps60
            customBitrateMbps = 60
            showCursor = true
            highlightClicks = true
        }
    }

    func apply(_ destination: ExportDestination) {
        exportDestination = destination

        switch destination {
        case .youtube:
            videoCodec = .h264
            frameRate = .fps60
            customBitrateMbps = max(customBitrateMbps, 45)
        case .linkedin:
            videoCodec = .h264
            frameRate = .fps30
            customBitrateMbps = 24
        case .website:
            videoCodec = .hevc
            frameRate = .fps30
            customBitrateMbps = 16
        case .archive:
            videoCodec = .h264
            frameRate = .fps60
            customBitrateMbps = 100
            videoQuality = .losslessLike
        }
    }
}

private enum Keys {
    static let selectedPreset = "selectedPreset"
    static let exportDestination = "exportDestination"
    static let includeMicrophone = "includeMicrophone"
    static let includeSystemAudio = "includeSystemAudio"
    static let showCursor = "showCursor"
    static let highlightClicks = "highlightClicks"
    static let countdownEnabled = "countdownEnabled"
    static let selectedMicrophoneID = "selectedMicrophoneID"
    static let outputFolderPath = "outputFolderPath"
    static let videoResolution = "videoResolution"
    static let videoQuality = "videoQuality"
    static let videoCodec = "videoCodec"
    static let frameRate = "frameRate"
    static let customBitrateMbps = "customBitrateMbps"
    static let clickHighlightColor = "clickHighlightColor"
    static let clickHighlightSize = "clickHighlightSize"
    static let hideAppDuringRecording = "hideAppDuringRecording"
}
