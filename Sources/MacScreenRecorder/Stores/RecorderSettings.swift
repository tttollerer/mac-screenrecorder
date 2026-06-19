import Foundation

final class RecorderSettings: ObservableObject {
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

    @Published var hideAppDuringRecording: Bool {
        didSet { defaults.set(hideAppDuringRecording, forKey: Keys.hideAppDuringRecording) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        hideAppDuringRecording = defaults.object(forKey: Keys.hideAppDuringRecording) as? Bool ?? true
    }
}

private enum Keys {
    static let includeMicrophone = "includeMicrophone"
    static let includeSystemAudio = "includeSystemAudio"
    static let showCursor = "showCursor"
    static let highlightClicks = "highlightClicks"
    static let countdownEnabled = "countdownEnabled"
    static let selectedMicrophoneID = "selectedMicrophoneID"
    static let outputFolderPath = "outputFolderPath"
    static let videoResolution = "videoResolution"
    static let videoQuality = "videoQuality"
    static let hideAppDuringRecording = "hideAppDuringRecording"
}
