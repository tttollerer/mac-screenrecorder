import AppKit
import SwiftUI

@MainActor
final class RecordingControlPanelService {
    private let state = RecordingControlPanelState()
    private var panel: NSPanel?

    func show(
        elapsedText: String,
        isPaused: Bool,
        isMicrophoneMuted: Bool,
        onPauseToggle: @escaping @MainActor () -> Void,
        onMicrophoneToggle: @escaping @MainActor () -> Void,
        onShowMainWindow: @escaping @MainActor () -> Void,
        onStop: @escaping @MainActor () -> Void
    ) {
        state.elapsedText = elapsedText
        state.isPaused = isPaused
        state.isMicrophoneMuted = isMicrophoneMuted

        if panel == nil {
            let rootView = RecordingControlPanelView(
                state: state,
                onPauseToggle: onPauseToggle,
                onMicrophoneToggle: onMicrophoneToggle,
                onShowMainWindow: onShowMainWindow,
                onStop: onStop
            )
            let hostingView = NSHostingView(rootView: rootView)
            let panelSize = CGSize(width: 382, height: 58)
            hostingView.frame = CGRect(origin: .zero, size: panelSize)

            let panel = NSPanel(
                contentRect: CGRect(origin: .zero, size: panelSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.contentView = hostingView
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.sharingType = .none
            panel.isMovableByWindowBackground = true

            if let screenFrame = NSScreen.main?.visibleFrame {
                let x = screenFrame.maxX - panelSize.width - 18
                let y = screenFrame.minY + 18
                panel.setFrameOrigin(CGPoint(x: x, y: y))
            }

            self.panel = panel
        }

        panel?.orderFrontRegardless()
    }

    func update(elapsedText: String, isPaused: Bool, isMicrophoneMuted: Bool) {
        state.elapsedText = elapsedText
        state.isPaused = isPaused
        state.isMicrophoneMuted = isMicrophoneMuted
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

@MainActor
private final class RecordingControlPanelState: ObservableObject {
    @Published var elapsedText = "00:00"
    @Published var isPaused = false
    @Published var isMicrophoneMuted = false
}

private struct RecordingControlPanelView: View {
    @ObservedObject var state: RecordingControlPanelState
    let onPauseToggle: @MainActor () -> Void
    let onMicrophoneToggle: @MainActor () -> Void
    let onShowMainWindow: @MainActor () -> Void
    let onStop: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(state.isPaused ? Color.orange : Color.red)
                .frame(width: 10, height: 10)

            Text(state.elapsedText)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .frame(width: 56, alignment: .leading)

            Button {
                onPauseToggle()
            } label: {
                Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help(state.isPaused ? "Fortsetzen" : "Pausieren")

            Button {
                onMicrophoneToggle()
            } label: {
                Image(systemName: state.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help(state.isMicrophoneMuted ? "Mikrofon einschalten" : "Mikrofon stumm")

            Button {
                onShowMainWindow()
            } label: {
                Image(systemName: "macwindow")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("Hauptfenster anzeigen")

            Button {
                onStop()
            } label: {
                Image(systemName: "stop.fill")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("Stoppen")
        }
        .padding(.horizontal, 14)
        .frame(width: 382, height: 58)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}
