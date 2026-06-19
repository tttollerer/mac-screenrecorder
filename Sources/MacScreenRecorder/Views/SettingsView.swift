import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var recorder: RecordingCoordinator

    var body: some View {
        Form {
            Section("Aufnahme") {
                Picker("Aufloesung", selection: $recorder.settings.videoResolution) {
                    ForEach(VideoResolution.allCases) { resolution in
                        Text("\(resolution.title) - \(resolution.detail)").tag(resolution)
                    }
                }
                Picker("Qualitaet", selection: $recorder.settings.videoQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text("\(quality.title) - \(quality.detail)").tag(quality)
                    }
                }
                Toggle("Countdown vor Aufnahme", isOn: $recorder.settings.countdownEnabled)
                Toggle("Fenster beim Start ausblenden", isOn: $recorder.settings.hideAppDuringRecording)
                Toggle("Cursor anzeigen", isOn: $recorder.settings.showCursor)
                Toggle("Klicks markieren", isOn: $recorder.settings.highlightClicks)
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
