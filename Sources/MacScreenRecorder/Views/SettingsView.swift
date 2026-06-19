import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        Form {
            Section("Presets") {
                Picker("Preset", selection: $recorder.settings.selectedPreset) {
                    ForEach(RecordingPreset.allCases) { preset in
                        Text("\(preset.title) - \(preset.detail)").tag(preset)
                    }
                }
                .onChange(of: recorder.settings.selectedPreset) { _, preset in
                    recorder.applyPreset(preset)
                }

                Picker("Exportziel", selection: $recorder.settings.exportDestination) {
                    ForEach(ExportDestination.allCases) { destination in
                        Text("\(destination.title) - \(destination.detail)").tag(destination)
                    }
                }
                .onChange(of: recorder.settings.exportDestination) { _, destination in
                    recorder.applyExportDestination(destination)
                }
            }

            Section("Aufnahme") {
                Picker("Aufloesung", selection: $recorder.settings.videoResolution) {
                    ForEach(VideoResolution.allCases) { resolution in
                        Text("\(resolution.title) - \(resolution.detail)").tag(resolution)
                    }
                }
                Picker("Codec", selection: $recorder.settings.videoCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text("\(codec.title) - \(codec.detail)").tag(codec)
                    }
                }
                Picker("Framerate", selection: $recorder.settings.frameRate) {
                    ForEach(FrameRate.allCases) { frameRate in
                        Text(frameRate.title).tag(frameRate)
                    }
                }
                Picker("Qualitaet", selection: $recorder.settings.videoQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text("\(quality.title) - \(quality.detail)").tag(quality)
                    }
                }
                Stepper(
                    recorder.settings.customBitrateMbps == 0
                        ? "Bitrate: Auto"
                        : "Bitrate: \(recorder.settings.customBitrateMbps) Mbit/s",
                    value: $recorder.settings.customBitrateMbps,
                    in: 0...120,
                    step: 2
                )
                Toggle("Countdown vor Aufnahme", isOn: $recorder.settings.countdownEnabled)
                Toggle("Fenster beim Start ausblenden", isOn: $recorder.settings.hideAppDuringRecording)
                Toggle("Cursor anzeigen", isOn: $recorder.settings.showCursor)
                Toggle("Klicks markieren", isOn: $recorder.settings.highlightClicks)
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

            Section("Audio") {
                Toggle("Mikrofon aufnehmen", isOn: $recorder.settings.includeMicrophone)
                Toggle("Systemaudio aufnehmen", isOn: $recorder.settings.includeSystemAudio)

                Picker("Standard-Mikrofon", selection: $recorder.settings.selectedMicrophoneID) {
                    ForEach(recorder.microphones) { microphone in
                        Text(microphone.name).tag(microphone.id)
                    }
                }
            }

            Section("Export") {
                HStack {
                    Text(recorder.settings.outputFolderPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Aendern") {
                        chooseOutputFolder()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .task {
            recorder.reloadMicrophones()
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Auswaehlen"
        panel.directoryURL = URL(fileURLWithPath: recorder.settings.outputFolderPath, isDirectory: true)

        if panel.runModal() == .OK, let url = panel.url {
            recorder.settings.outputFolderPath = url.path
        }
    }
}
