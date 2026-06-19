import AppKit
@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

private final class UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

enum ScreenCaptureTarget {
    case display(SCDisplay, crop: CGRect?)
    case window(SCWindow)

    var title: String {
        switch self {
        case .display:
            "Bildschirm"
        case .window(let window):
            window.title ?? window.owningApplication?.applicationName ?? "Fenster"
        }
    }

    var pixelSize: CGSize {
        switch self {
        case .display(let display, let crop):
            if let crop {
                return CGSize(width: crop.width, height: crop.height)
            }
            return CGSize(width: display.width * 2, height: display.height * 2)
        case .window(let window):
            return CGSize(width: max(2, window.frame.width * 2), height: max(2, window.frame.height * 2))
        }
    }
}

struct CaptureEngineConfiguration {
    let target: ScreenCaptureTarget
    let outputURL: URL
    let includeMicrophone: Bool
    let includeSystemAudio: Bool
    let microphoneID: String
    let showCursor: Bool
    let videoResolution: VideoResolution
    let videoQuality: VideoQuality
    let clickMarkerStore: ClickMarkerStore?
}

final class ScreenCaptureRecorder: NSObject, @unchecked Sendable {
    private enum CapturedMedia {
        case video
        case systemAudio
        case microphone
    }

    private let configuration: CaptureEngineConfiguration
    private let sampleQueue = DispatchQueue(label: "app.macscreenrecorder.capture.samples")
    private let writerQueue = DispatchQueue(label: "app.macscreenrecorder.capture.writer")

    private var stream: SCStream?
    private var microphoneSession: AVCaptureSession?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var systemAudioInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?
    private var baseTime: CMTime?
    private var accumulatedPausedDuration = CMTime.zero
    private var pauseStartedTime: CMTime?
    private var pendingResume = false
    private var isPaused = false
    private var isFinishing = false

    init(configuration: CaptureEngineConfiguration) {
        self.configuration = configuration
        super.init()
    }

    func start() async throws {
        try prepareAssetWriter()
        try await prepareScreenStream()

        if configuration.includeMicrophone {
            try prepareMicrophoneSession()
        }

        try await stream?.startCapture()
        microphoneSession.map { session in
            sampleQueue.async {
                session.startRunning()
            }
        }
    }

    func stop() async throws -> URL {
        isFinishing = true
        if let stream {
            try await stream.stopCapture()
        }
        microphoneSession?.stopRunning()
        microphoneSession = nil
        stream = nil

        return try await finishWriting()
    }

    func pause() {
        writerQueue.async { [weak self] in
            guard let self, !self.isFinishing else { return }
            self.isPaused = true
            self.pendingResume = false
        }
    }

    func resume() {
        writerQueue.async { [weak self] in
            guard let self, !self.isFinishing else { return }
            self.isPaused = false
            self.pendingResume = true
        }
    }

    private func prepareAssetWriter() throws {
        let writer = try AVAssetWriter(outputURL: configuration.outputURL, fileType: .mp4)
        let size = configuration.videoResolution.outputSize(for: configuration.target.pixelSize)
        let width = Self.evenPixel(max(2, Int(size.width)))
        let height = Self.evenPixel(max(2, Int(size.height)))
        let bitrate = max(configuration.videoQuality.minimumBitrate, width * height * configuration.videoQuality.bitsPerPixel)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoAllowFrameReorderingKey: false,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ]

        let video = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        video.expectsMediaDataInRealTime = true
        guard writer.canAdd(video) else {
            throw RecordingError.cannotAddVideoInput
        }
        writer.add(video)
        videoInput = video

        if configuration.includeSystemAudio {
            let input = makeAudioInput()
            guard writer.canAdd(input) else {
                throw RecordingError.cannotAddAudioInput
            }
            writer.add(input)
            systemAudioInput = input
        }

        if configuration.includeMicrophone {
            let input = makeAudioInput()
            guard writer.canAdd(input) else {
                throw RecordingError.cannotAddAudioInput
            }
            writer.add(input)
            microphoneInput = input
        }

        assetWriter = writer
    }

    private func prepareScreenStream() async throws {
        let filter: SCContentFilter
        let streamConfiguration = SCStreamConfiguration()
        let size = configuration.videoResolution.outputSize(for: configuration.target.pixelSize)

        streamConfiguration.width = Self.evenPixel(max(2, Int(size.width)))
        streamConfiguration.height = Self.evenPixel(max(2, Int(size.height)))
        streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        streamConfiguration.queueDepth = 6
        streamConfiguration.showsCursor = configuration.showCursor
        streamConfiguration.capturesAudio = configuration.includeSystemAudio
        streamConfiguration.excludesCurrentProcessAudio = true
        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfiguration.scalesToFit = false

        switch configuration.target {
        case .display(let display, let crop):
            filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            if let crop {
                streamConfiguration.sourceRect = crop
            }
        case .window(let window):
            filter = SCContentFilter(desktopIndependentWindow: window)
        }

        let stream = SCStream(filter: filter, configuration: streamConfiguration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        if configuration.includeSystemAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        }
        self.stream = stream
    }

    private func prepareMicrophoneSession() throws {
        let session = AVCaptureSession()
        session.beginConfiguration()

        let device = microphoneDevice(id: configuration.microphoneID)
        guard let device else {
            throw RecordingError.microphoneUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw RecordingError.microphoneUnavailable
        }
        session.addInput(input)

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        guard session.canAddOutput(output) else {
            throw RecordingError.microphoneUnavailable
        }
        session.addOutput(output)

        session.commitConfiguration()
        microphoneSession = session
    }

    private func makeAudioInput() -> AVAssetWriterInput {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192_000
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        return input
    }

    private func microphoneDevice(id: String) -> AVCaptureDevice? {
        if !id.isEmpty {
            return Self.availableMicrophones().first { $0.uniqueID == id }
        }
        return AVCaptureDevice.default(for: .audio)
    }

    private static func availableMicrophones() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    private func append(_ sampleBuffer: CMSampleBuffer, media: CapturedMedia) {
        guard CMSampleBufferIsValid(sampleBuffer), CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }

        writerQueue.async { [weak self] in
            guard let self, !self.isFinishing, let writer = self.assetWriter else {
                return
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if self.baseTime == nil {
                guard media == .video else { return }
                self.baseTime = presentationTime
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)
            }

            guard writer.status == .writing, let baseTime = self.baseTime else {
                return
            }

            if self.isPaused {
                if self.pauseStartedTime == nil {
                    self.pauseStartedTime = presentationTime
                }
                return
            }

            if self.pendingResume {
                if let pauseStartedTime = self.pauseStartedTime {
                    self.accumulatedPausedDuration = self.accumulatedPausedDuration + (presentationTime - pauseStartedTime)
                }
                self.pauseStartedTime = nil
                self.pendingResume = false
            }

            if media == .video {
                self.drawClickMarkers(on: sampleBuffer)
            }

            let adjustedBaseTime = baseTime + self.accumulatedPausedDuration
            guard let retimedBuffer = Self.copy(sampleBuffer, subtracting: adjustedBaseTime) else {
                return
            }

            switch media {
            case .video:
                if self.videoInput?.isReadyForMoreMediaData == true {
                    self.videoInput?.append(retimedBuffer)
                }
            case .systemAudio:
                if self.systemAudioInput?.isReadyForMoreMediaData == true {
                    self.systemAudioInput?.append(retimedBuffer)
                }
            case .microphone:
                if self.microphoneInput?.isReadyForMoreMediaData == true {
                    self.microphoneInput?.append(retimedBuffer)
                }
            }
        }
    }

    private func finishWriting() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            writerQueue.async { [weak self] in
                guard let self, let writer = self.assetWriter else {
                    continuation.resume(throwing: RecordingError.writerUnavailable)
                    return
                }

                self.videoInput?.markAsFinished()
                self.systemAudioInput?.markAsFinished()
                self.microphoneInput?.markAsFinished()

                if writer.status == .unknown {
                    continuation.resume(returning: self.configuration.outputURL)
                    return
                }

                let writerBox = UncheckedSendableBox(writer)
                writer.finishWriting {
                    let finishedWriter = writerBox.value
                    if finishedWriter.status == .failed {
                        continuation.resume(throwing: finishedWriter.error ?? RecordingError.writerFailed)
                    } else {
                        continuation.resume(returning: self.configuration.outputURL)
                    }
                }
            }
        }
    }

    private static func copy(_ sampleBuffer: CMSampleBuffer, subtracting baseTime: CMTime) -> CMSampleBuffer? {
        var entriesNeeded = 0
        CMSampleBufferGetSampleTimingInfoArray(
            sampleBuffer,
            entryCount: 0,
            arrayToFill: nil,
            entriesNeededOut: &entriesNeeded
        )

        var timing = Array(
            repeating: CMSampleTimingInfo(
                duration: .invalid,
                presentationTimeStamp: .invalid,
                decodeTimeStamp: .invalid
            ),
            count: entriesNeeded
        )

        CMSampleBufferGetSampleTimingInfoArray(
            sampleBuffer,
            entryCount: entriesNeeded,
            arrayToFill: &timing,
            entriesNeededOut: &entriesNeeded
        )

        for index in timing.indices {
            if timing[index].presentationTimeStamp.isValid {
                timing[index].presentationTimeStamp = timing[index].presentationTimeStamp - baseTime
            }
            if timing[index].decodeTimeStamp.isValid {
                timing[index].decodeTimeStamp = timing[index].decodeTimeStamp - baseTime
            }
        }

        var copiedBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: entriesNeeded,
            sampleTimingArray: &timing,
            sampleBufferOut: &copiedBuffer
        )
        return copiedBuffer
    }

    private static func evenPixel(_ value: Int) -> Int {
        value.isMultiple(of: 2) ? value : value - 1
    }

    private func drawClickMarkers(on sampleBuffer: CMSampleBuffer) {
        guard let markerStore = configuration.clickMarkerStore,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let events = markerStore.events(activeAt: Date())
        guard !events.isEmpty else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return
        }

        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let outputSize = CGSize(width: width, height: height)
        for event in events {
            guard let point = videoPoint(for: event.globalPoint, outputSize: outputSize) else {
                continue
            }

            let age = Date().timeIntervalSince(event.timestamp)
            let progress = min(1, max(0, age / 0.55))
            let alpha = max(0, 1 - progress)
            let radius = 16 + progress * 44
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            context.setStrokeColor((event.isRightClick ? NSColor.systemOrange : NSColor.systemBlue).withAlphaComponent(alpha * 0.92).cgColor)
            context.setLineWidth(6)
            context.strokeEllipse(in: rect)

            context.setStrokeColor(NSColor.white.withAlphaComponent(alpha * 0.92).cgColor)
            context.setLineWidth(2.5)
            context.strokeEllipse(in: rect.insetBy(dx: 9, dy: 9))
        }

        context.restoreGState()
    }

    private func videoPoint(for globalPoint: CGPoint, outputSize: CGSize) -> CGPoint? {
        switch configuration.target {
        case .display(let display, let crop):
            guard let screen = NSScreen.screen(with: display.displayID) else {
                return nil
            }

            let sourceRect = crop ?? CGRect(x: 0, y: 0, width: display.width, height: display.height)
            let localX = globalPoint.x - screen.frame.minX
            let localYFromBottom = globalPoint.y - screen.frame.minY
            let sourceX = localX - sourceRect.minX
            let sourceYFromBottom = localYFromBottom - sourceRect.minY

            guard sourceX >= 0,
                  sourceYFromBottom >= 0,
                  sourceX <= sourceRect.width,
                  sourceYFromBottom <= sourceRect.height else {
                return nil
            }

            return CGPoint(
                x: sourceX * outputSize.width / sourceRect.width,
                y: (sourceRect.height - sourceYFromBottom) * outputSize.height / sourceRect.height
            )

        case .window(let window):
            let frame = window.frame
            let sourceX = globalPoint.x - frame.minX
            let sourceYFromBottom = globalPoint.y - frame.minY

            guard sourceX >= 0,
                  sourceYFromBottom >= 0,
                  sourceX <= frame.width,
                  sourceYFromBottom <= frame.height else {
                return nil
            }

            return CGPoint(
                x: sourceX * outputSize.width / frame.width,
                y: (frame.height - sourceYFromBottom) * outputSize.height / frame.height
            )
        }
    }
}

private extension NSScreen {
    static func screen(with displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return number.uint32Value == displayID
        }
    }
}

extension ScreenCaptureRecorder: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            append(sampleBuffer, media: .video)
        case .audio:
            append(sampleBuffer, media: .systemAudio)
        case .microphone:
            append(sampleBuffer, media: .microphone)
        @unknown default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        isFinishing = true
    }
}

extension ScreenCaptureRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        append(sampleBuffer, media: .microphone)
    }
}

enum RecordingError: LocalizedError {
    case cannotAddVideoInput
    case cannotAddAudioInput
    case microphoneUnavailable
    case writerUnavailable
    case writerFailed

    var errorDescription: String? {
        switch self {
        case .cannotAddVideoInput:
            "Videoeingang konnte nicht erstellt werden."
        case .cannotAddAudioInput:
            "Audioeingang konnte nicht erstellt werden."
        case .microphoneUnavailable:
            "Das Mikrofon ist nicht verfuegbar."
        case .writerUnavailable:
            "Der Exportprozess ist nicht verfuegbar."
        case .writerFailed:
            "Die Aufnahme konnte nicht geschrieben werden."
        }
    }
}
