import SwiftUI

@main
struct MacScreenRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var recorder = RecordingCoordinator()

    var body: some Scene {
        WindowGroup("Mac Screenrecorder", id: "main") {
            ContentView()
                .environmentObject(recorder)
                .frame(minWidth: 980, minHeight: 820)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button(recorder.isRecording ? "Aufnahme stoppen" : "Aufnahme starten") {
                    Task { await recorder.toggleRecording() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("Recorder", systemImage: recorder.isRecording ? "record.circle.fill" : "video.circle") {
            Text(recorder.menuStatusText)
                .foregroundStyle(.secondary)

            Button(recorder.isRecording ? "Aufnahme stoppen" : "Aufnahme starten") {
                Task { await recorder.toggleRecording() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Fenster anzeigen") {
                openWindow(id: "main")
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Video im Editor oeffnen") {
                recorder.chooseVideoForEditor()
            }

            Toggle("Fenster ausblenden", isOn: $recorder.settings.hideAppDuringRecording)

            if let lastURL = recorder.lastRecordingURL {
                Button("Letzte Aufnahme oeffnen") {
                    NSWorkspace.shared.activateFileViewerSelecting([lastURL])
                }
            }

            Divider()

            SettingsLink {
                Label("Einstellungen", systemImage: "gearshape")
            }

            Button("Beenden") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
                .environmentObject(recorder)
                .frame(width: 560)
        }
    }
}
