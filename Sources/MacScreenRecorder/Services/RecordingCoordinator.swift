import AppKit
@preconcurrency import AVFoundation
import Foundation
import ScreenCaptureKit
import UniformTypeIdentifiers

@MainActor
final class RecordingCoordinator: ObservableObject {
    @Published var captureMode: CaptureMode = .display {
        didSet { selectDefaultSourceForMode() }
    }
    @Published var selectedSourceID: String?
    @Published var sources: [CaptureSource] = []
    @Published var microphones: [AudioInputDevice] = [.systemDefault]
    @Published var state: RecordingState = .idle
    @Published var lastRecordingURL: URL?
    @Published var activeEditorURL: URL?
    @Published var statusMessage: String?
    @Published var elapsedSeconds: Int = 0
    @Published var screenPermissionGranted = true
    @Published var selectedRegion: SelectedCaptureRegion?

    @Published var settings = RecorderSettings()

    private var displaysByID: [CGDirectDisplayID: SCDisplay] = [:]
    private var windowsByID: [UInt32: SCWindow] = [:]
    private var recorder: ScreenCaptureRecorder?
    private var elapsedTimer: Timer?
    private var hiddenRecordingWindows: [NSWindow] = []
    private let clickMarkerStore = ClickMarkerStore()
    private lazy var clickHighlighter = ClickHighlighterService(markerStore: clickMarkerStore)
    private let recordingControlPanel = RecordingControlPanelService()
    private let regionSelectionService = RegionSelectionService()

    var isRecording: Bool {
        switch state {
        case .recording, .paused:
            true
        default:
            false
        }
    }

    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    var visibleSources: [CaptureSource] {
        switch captureMode {
        case .display, .region:
            sources.filter { $0.kind == .display }
        case .window:
            sources.filter { $0.kind == .window }
        }
    }

    var microphonePermissionGranted: Bool {
        PermissionService.microphoneStatus == .authorized
    }

    var menuStatusText: String {
        switch state {
        case .idle:
            "Bereit"
        case .preparing:
            "Vorbereiten"
        case .countdown(let value):
            "Start in \(value)"
        case .recording:
            "Laeuft \(formattedElapsedTime)"
        case .paused:
            "Pausiert \(formattedElapsedTime)"
        case .stopping:
            "Speichern"
        case .failed:
            "Fehler"
        }
    }

    var formattedElapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init() {
        reloadMicrophones()
        Task { await refreshSources() }
    }

    func refreshSources() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            screenPermissionGranted = true
            displaysByID = Dictionary(uniqueKeysWithValues: content.displays.map { ($0.displayID, $0) })
            windowsByID = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })

            let displaySources = content.displays.map { display in
                CaptureSource(
                    id: "display-\(display.displayID)",
                    kind: .display,
                    title: display.displayID == CGMainDisplayID() ? "Hauptbildschirm" : "Bildschirm \(display.displayID)",
                    subtitle: "Display",
                    displayID: display.displayID,
                    windowID: nil,
                    width: display.width,
                    height: display.height
                )
            }

            let windowSources = content.windows
                .filter { window in
                    guard window.isOnScreen else { return false }
                    let title = window.title ?? ""
                    let appName = window.owningApplication?.applicationName ?? ""
                    return !title.isEmpty || !appName.isEmpty
                }
                .sorted { lhs, rhs in
                    let left = lhs.owningApplication?.applicationName ?? lhs.title ?? ""
                    let right = rhs.owningApplication?.applicationName ?? rhs.title ?? ""
                    return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                }
                .prefix(40)
                .map { window in
                    let appName = window.owningApplication?.applicationName ?? "App"
                    let title = window.title?.isEmpty == false ? window.title! : appName
                    return CaptureSource(
                        id: "window-\(window.windowID)",
                        kind: .window,
                        title: title,
                        subtitle: appName,
                        displayID: nil,
                        windowID: window.windowID,
                        width: max(2, Int(window.frame.width)),
                        height: max(2, Int(window.frame.height))
                    )
                }

            sources = displaySources + windowSources
            selectDefaultSourceForMode()
            statusMessage = nil
        } catch {
            screenPermissionGranted = false
            sources = []
            displaysByID = [:]
            windowsByID = [:]
            statusMessage = "Quellen konnten nicht geladen werden: \(error.localizedDescription)"
        }
    }

    func reloadMicrophones() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        .devices
            .map { AudioInputDevice(id: $0.uniqueID, name: $0.localizedName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        microphones = [.systemDefault] + devices
    }

    func requestScreenPermission() {
        PermissionService.requestScreenRecordingPermission()
    }

    func requestMicrophonePermission() async {
        _ = await PermissionService.requestMicrophonePermission()
    }

    func openScreenSettings() {
        PermissionService.openScreenRecordingSettings()
    }

    func resetScreenPermission() {
        do {
            try PermissionService.resetScreenRecordingPermission()
            screenPermissionGranted = false
            statusMessage = "Bildschirmaufnahme wurde zurueckgesetzt. In Systemeinstellungen erneut aktivieren und App neu starten."
            PermissionService.openScreenRecordingSettings()
        } catch {
            statusMessage = "Reset fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func openMicrophoneSettings() {
        PermissionService.openMicrophoneSettings()
    }

    func relaunchApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]

        do {
            try process.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NSApp.terminate(nil)
            }
        } catch {
            statusMessage = "Neustart fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func openEditor(for url: URL) {
        activeEditorURL = url
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openLastRecordingOrChooseVideoForEditor() {
        if let lastRecordingURL {
            openEditor(for: lastRecordingURL)
        } else {
            chooseVideoForEditor()
        }
    }

    func chooseVideoForEditor() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.prompt = "Oeffnen"
        panel.message = "Video zum Schneiden auswaehlen"

        if panel.runModal() == .OK, let url = panel.url {
            lastRecordingURL = url
            openEditor(for: url)
        }
    }

    func closeEditor() {
        activeEditorURL = nil
    }

    func selectRecordingRegion() async {
        guard let source = selectedCaptureSource(), let displayID = source.displayID else {
            statusMessage = "Bitte zuerst einen Bildschirm fuer den Bereich auswaehlen."
            return
        }

        guard let screen = NSScreen.screen(with: displayID), let display = displaysByID[displayID] else {
            statusMessage = "Der ausgewaehlte Bildschirm ist nicht verfuegbar."
            return
        }

        hideMainInterfaceForRecording()
        defer {
            showMainInterfaceAfterRecording()
        }

        guard let globalRect = await regionSelectionService.selectRegion(on: screen) else {
            statusMessage = "Bereichsauswahl abgebrochen."
            return
        }

        let sourceRect = convertGlobalRectToSourceRect(
            globalRect,
            screenFrame: screen.frame,
            displaySize: CGSize(width: display.width, height: display.height)
        )

        guard sourceRect.width >= 40, sourceRect.height >= 40 else {
            statusMessage = "Der ausgewaehlte Bereich ist zu klein."
            return
        }

        selectedRegion = SelectedCaptureRegion(displayID: displayID, sourceRect: sourceRect)
        statusMessage = "Bereich ausgewaehlt: \(Int(sourceRect.width))x\(Int(sourceRect.height))"
    }

    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    func startRecording() async {
        guard !isRecording else { return }
        state = .preparing
        statusMessage = nil

        if settings.includeMicrophone && PermissionService.microphoneStatus != .authorized {
            let granted = await PermissionService.requestMicrophonePermission()
            guard granted else {
                state = .failed("Mikrofonzugriff ist nicht erlaubt.")
                return
            }
        }

        if sources.isEmpty {
            await refreshSources()
        }

        guard let selectedSource = selectedCaptureSource(), let target = captureTarget(for: selectedSource) else {
            state = .failed("Keine Aufnahmequelle verfuegbar. Bitte Bildschirmaufnahme erlauben und Aktualisieren klicken.")
            return
        }

        do {
            if settings.hideAppDuringRecording {
                hideMainInterfaceForRecording()
            }
            if settings.highlightClicks {
                clickHighlighter.start()
            }

            if settings.countdownEnabled {
                for value in stride(from: 3, through: 1, by: -1) {
                    state = .countdown(value)
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }

            let outputURL = try RecordingFileNamer.makeOutputURL(
                in: settings.outputFolderPath,
                sourceTitle: selectedSource.title
            )

            let engine = ScreenCaptureRecorder(
                configuration: CaptureEngineConfiguration(
                    target: target,
                    outputURL: outputURL,
                    includeMicrophone: settings.includeMicrophone,
                    includeSystemAudio: settings.includeSystemAudio,
                    microphoneID: settings.selectedMicrophoneID,
                    showCursor: settings.showCursor,
                    videoResolution: settings.videoResolution,
                    videoQuality: settings.videoQuality,
                    clickMarkerStore: settings.highlightClicks ? clickMarkerStore : nil
                )
            )

            try await engine.start()
            recorder = engine
            state = .recording(startedAt: Date())
            elapsedSeconds = 0
            startElapsedTimer()
            showRecordingControls()
        } catch {
            recorder = nil
            clickHighlighter.stop()
            recordingControlPanel.close()
            showMainInterfaceAfterRecording()
            state = .failed(error.localizedDescription)
        }
    }

    func pauseRecording() {
        guard case .recording = state, let recorder else { return }
        recorder.pause()
        state = .paused
        recordingControlPanel.update(elapsedText: formattedElapsedTime, isPaused: true)
    }

    func resumeRecording() {
        guard case .paused = state, let recorder else { return }
        clickMarkerStore.clear()
        recorder.resume()
        state = .recording(startedAt: Date())
        recordingControlPanel.update(elapsedText: formattedElapsedTime, isPaused: false)
    }

    func togglePauseRecording() {
        if isPaused {
            resumeRecording()
        } else {
            pauseRecording()
        }
    }

    func stopRecording() async {
        guard let recorder else { return }
        state = .stopping
        stopElapsedTimer()
        clickHighlighter.stop()
        recordingControlPanel.close()

        do {
            let url = try await recorder.stop()
            self.recorder = nil
            lastRecordingURL = url
            activeEditorURL = url
            state = .idle
            statusMessage = "Aufnahme gespeichert: \(url.lastPathComponent)"
            showMainInterfaceAfterRecording()
        } catch {
            self.recorder = nil
            state = .failed(error.localizedDescription)
            showMainInterfaceAfterRecording()
        }
    }

    private func selectDefaultSourceForMode() {
        let available = visibleSources
        if let selectedSourceID, available.contains(where: { $0.id == selectedSourceID }) {
            return
        }
        selectedSourceID = available.first?.id
    }

    private func selectedCaptureSource() -> CaptureSource? {
        let available = visibleSources
        if let selectedSourceID, let source = available.first(where: { $0.id == selectedSourceID }) {
            return source
        }
        return available.first
    }

    private func captureTarget(for source: CaptureSource) -> ScreenCaptureTarget? {
        switch captureMode {
        case .display:
            guard let displayID = source.displayID, let display = displaysByID[displayID] else { return nil }
            return .display(display, crop: nil)
        case .region:
            guard let displayID = source.displayID, let display = displaysByID[displayID] else { return nil }
            if let selectedRegion, selectedRegion.displayID == displayID {
                return .display(display, crop: selectedRegion.sourceRect)
            }
            return nil
        case .window:
            guard let windowID = source.windowID, let window = windowsByID[windowID] else { return nil }
            return .window(window)
        }
    }

    private func hideMainInterfaceForRecording() {
        hiddenRecordingWindows = NSApp.windows.filter { window in
            window.isVisible && !(window is ClickHighlightWindow)
        }
        hiddenRecordingWindows.forEach { $0.orderOut(nil) }
    }

    private func showMainInterfaceAfterRecording() {
        hiddenRecordingWindows.forEach { $0.makeKeyAndOrderFront(nil) }
        hiddenRecordingWindows = []
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if !self.isPaused {
                    self.elapsedSeconds += 1
                }
                self.recordingControlPanel.update(elapsedText: self.formattedElapsedTime, isPaused: self.isPaused)
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func showRecordingControls() {
        recordingControlPanel.show(
            elapsedText: formattedElapsedTime,
            isPaused: isPaused,
            onPauseToggle: { [weak self] in
                self?.togglePauseRecording()
            },
            onStop: { [weak self] in
                Task { await self?.stopRecording() }
            }
        )
    }

    private func convertGlobalRectToSourceRect(
        _ globalRect: CGRect,
        screenFrame: CGRect,
        displaySize: CGSize
    ) -> CGRect {
        let scaleX = displaySize.width / screenFrame.width
        let scaleY = displaySize.height / screenFrame.height
        let localMinX = globalRect.minX - screenFrame.minX
        let localMaxY = globalRect.maxY - screenFrame.minY

        return CGRect(
            x: max(0, localMinX * scaleX),
            y: max(0, (screenFrame.height - localMaxY) * scaleY),
            width: min(displaySize.width, globalRect.width * scaleX),
            height: min(displaySize.height, globalRect.height * scaleY)
        ).integral
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
