import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        Group {
            if let editorURL = recorder.activeEditorURL {
                VideoEditorView(recordingURL: editorURL)
            } else {
                VStack(spacing: 0) {
                    HeaderView()
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .padding(.bottom, 16)

                    Divider()

                    HStack(alignment: .top, spacing: 22) {
                        VStack(spacing: 14) {
                            PresetSection()
                            PermissionBanner()
                            SourceSection()
                            VideoSection()
                            AudioSection()
                        }
                        .frame(width: 430)

                        VStack(spacing: 14) {
                            RecordingActionPanel()
                            LastRecordingPanel()
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(24)
                }
            }
        }
        .task {
            await recorder.refreshSources()
            recorder.reloadMicrophones()
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mac Screenrecorder")
                    .font(.system(size: 22, weight: .semibold))
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await recorder.refreshSources() }
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
            }
            .controlSize(.large)
        }
    }

    private var statusText: String {
        switch recorder.state {
        case .idle:
            recorder.statusMessage ?? "Bereit fuer die naechste Web-App-Demo"
        case .preparing:
            "Aufnahme wird vorbereitet"
        case .countdown(let value):
            "Start in \(value)"
        case .recording:
            "Aufnahme laeuft"
        case .paused:
            "Aufnahme pausiert"
        case .stopping:
            "Aufnahme wird gespeichert"
        case .failed(let message):
            message
        }
    }
}

private struct PermissionBanner: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        if !recorder.screenPermissionGranted || (recorder.settings.includeMicrophone && !recorder.microphonePermissionGranted) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Berechtigungen", systemImage: "lock.shield")
                    .font(.headline)

                if !recorder.screenPermissionGranted {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bildschirmaufnahme fehlt oder ist fuer diesen App-Start noch nicht aktiv.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Button("Systemeinstellungen") {
                                recorder.openScreenSettings()
                            }

                            Button("Reset") {
                                recorder.resetScreenPermission()
                            }

                            Button("App neu starten") {
                                recorder.relaunchApp()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if recorder.settings.includeMicrophone && !recorder.microphonePermissionGranted {
                    HStack {
                        Text("Mikrofonzugriff fehlt")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Erlauben") {
                            Task { await recorder.requestMicrophonePermission() }
                            recorder.openMicrophoneSettings()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct PresetSection: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Preset", systemImage: "wand.and.stars")
                .font(.headline)

            Picker("Preset", selection: $recorder.settings.selectedPreset) {
                ForEach(RecordingPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: recorder.settings.selectedPreset) { _, preset in
                recorder.applyPreset(preset)
            }

            Text(recorder.settings.selectedPreset.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SourceSection: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quelle", systemImage: "rectangle.on.rectangle")
                .font(.headline)

            Picker("Quelle", selection: $recorder.captureMode) {
                ForEach(CaptureMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Button {
                    recorder.selectBrowserWindow()
                } label: {
                    Label("Browser suchen", systemImage: "safari")
                }

                if recorder.captureMode == .region {
                    Button {
                        Task { await recorder.selectRecordingRegion() }
                    } label: {
                        Label("Bereich ziehen", systemImage: "selection.pin.in.out")
                    }
                }

                Spacer()
            }

            List(recorder.visibleSources, selection: $recorder.selectedSourceID) { source in
                SourceRow(source: source, captureMode: recorder.captureMode)
                    .tag(source.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        recorder.activateSource(source)
                    }
                    .onTapGesture(count: 2) {
                        recorder.openLastRecordingOrChooseVideoForEditor()
                    }
            }
            .frame(height: 146)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if recorder.captureMode == .region {
                HStack {
                    Button {
                        Task { await recorder.selectRecordingRegion() }
                    } label: {
                        Label("Bereich auswaehlen", systemImage: "selection.pin.in.out")
                    }

                    Spacer()

                    Text(regionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var regionLabel: String {
        recorder.selectedRegion?.sizeLabel ?? "Kein Bereich"
    }
}

private struct SourceRow: View {
    let source: CaptureSource
    let captureMode: CaptureMode

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: captureMode == .window ? "macwindow" : "display")
                .frame(width: 18)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Text("\(source.subtitle) - \(sizeLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    private var title: String {
        if captureMode == .region {
            return "Demo-Bereich auf \(source.title)"
        }
        return source.title
    }

    private var sizeLabel: String {
        if captureMode == .region {
            return source.sizeLabel
        }
        return source.sizeLabel
    }
}

private struct VideoSection: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Video", systemImage: "rectangle.inset.filled")
                .font(.headline)

            Picker("Aufloesung", selection: $recorder.settings.videoResolution) {
                ForEach(VideoResolution.allCases) { resolution in
                    Text(resolution.title).tag(resolution)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(recorder.settings.videoResolution.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Codec", selection: $recorder.settings.videoCodec) {
                ForEach(VideoCodec.allCases) { codec in
                    Text(codec.title).tag(codec)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker("FPS", selection: $recorder.settings.frameRate) {
                ForEach(FrameRate.allCases) { frameRate in
                    Text(frameRate.title).tag(frameRate)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker("Qualitaet", selection: $recorder.settings.videoQuality) {
                ForEach(VideoQuality.allCases) { quality in
                    Text(quality.title).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(recorder.settings.videoQuality.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Bitrate")
                Spacer()
                Text(bitrateLabel)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(recorder.settings.customBitrateMbps) },
                    set: { recorder.settings.customBitrateMbps = Int($0.rounded()) }
                ),
                in: 0...120,
                step: 2
            )

            Picker("Exportziel", selection: $recorder.settings.exportDestination) {
                ForEach(ExportDestination.allCases) { destination in
                    Text(destination.title).tag(destination)
                }
            }
            .onChange(of: recorder.settings.exportDestination) { _, destination in
                recorder.applyExportDestination(destination)
            }

            Text(recorder.settings.exportDestination.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var bitrateLabel: String {
        recorder.settings.customBitrateMbps == 0 ? "Auto" : "\(recorder.settings.customBitrateMbps) Mbit/s"
    }
}

private struct AudioSection: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Audio", systemImage: "waveform")
                .font(.headline)

            Toggle(isOn: $recorder.settings.includeMicrophone) {
                Label("Mikrofon", systemImage: "mic")
            }

            Picker("Eingang", selection: $recorder.settings.selectedMicrophoneID) {
                ForEach(recorder.microphones) { microphone in
                    Text(microphone.name).tag(microphone.id)
                }
            }
            .disabled(!recorder.settings.includeMicrophone)

            LevelMeter(title: "Mic-Pegel", level: recorder.microphoneLevel)

            Toggle(isOn: $recorder.settings.includeSystemAudio) {
                Label("Systemaudio", systemImage: "speaker.wave.2")
            }

            LevelMeter(title: "System-Pegel", level: recorder.systemAudioLevel)

            Toggle(isOn: $recorder.settings.showCursor) {
                Label("Cursor anzeigen", systemImage: "cursorarrow")
            }

            Toggle(isOn: $recorder.settings.highlightClicks) {
                Label("Klicks markieren", systemImage: "cursorarrow.click.2")
            }

            if recorder.settings.highlightClicks {
                Picker("Klickfarbe", selection: $recorder.settings.clickHighlightColor) {
                    ForEach(ClickHighlightColor.allCases) { color in
                        Text(color.title).tag(color)
                    }
                }

                Picker("Klickgroesse", selection: $recorder.settings.clickHighlightSize) {
                    ForEach(ClickHighlightSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct LevelMeter: View {
    let title: String
    let level: Float

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(levelColor)
                        .frame(width: proxy.size.width * CGFloat(min(1, max(0, level))))
                }
            }
            .frame(height: 7)
        }
    }

    private var levelColor: Color {
        if level > 0.82 { return .red }
        if level > 0.58 { return .orange }
        return .accentColor
    }
}

private struct RecordingActionPanel: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(indicatorColor.opacity(0.14))
                    .frame(width: 108, height: 108)
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 66, height: 66)
                    .overlay {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }

            Text(timerText)
                .font(.system(size: 34, weight: .medium, design: .monospaced))
                .contentTransition(.numericText())

            Button {
                Task { await recorder.toggleRecording() }
            } label: {
                Label(buttonTitle, systemImage: recorder.isRecording ? "stop.fill" : "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isButtonDisabled)

            Button {
                recorder.chooseVideoForEditor()
            } label: {
                Label("Video im Editor oeffnen", systemImage: "folder.badge.play")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(recorder.isRecording)

            Toggle("Countdown", isOn: $recorder.settings.countdownEnabled)
                .toggleStyle(.switch)

            Toggle("Fenster beim Start ausblenden", isOn: $recorder.settings.hideAppDuringRecording)
                .toggleStyle(.switch)
                .help("Start und Stop bleiben ueber das Menueleisten-Icon erreichbar.")
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var indicatorColor: Color {
        recorder.isRecording ? .red : .accentColor
    }

    private var buttonTitle: String {
        switch recorder.state {
        case .preparing:
            "Vorbereiten"
        case .countdown(let value):
            "Start in \(value)"
        case .recording:
            "Stoppen"
        case .paused:
            "Stoppen"
        case .stopping:
            "Speichern"
        default:
            "Aufnehmen"
        }
    }

    private var timerText: String {
        recorder.formattedElapsedTime
    }

    private var isButtonDisabled: Bool {
        switch recorder.state {
        case .preparing, .countdown, .stopping:
            true
        default:
            false
        }
    }
}

private struct LastRecordingPanel: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Letzte Aufnahme", systemImage: "film")
                .font(.headline)

            if let url = recorder.lastRecordingURL {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                        Text(url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        recorder.openEditor(for: url)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .help("Bearbeiten")

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Im Finder zeigen")

                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Teilen")
                }
            } else {
                Text("Noch keine Aufnahme in dieser Sitzung")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
