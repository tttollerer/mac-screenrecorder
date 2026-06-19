import AppKit
import SwiftUI

@MainActor
final class RecordingControlPanelService {
    private let state = RecordingControlPanelState()
    private var panel: NSPanel?

    func show(
        elapsedText: String,
        isPaused: Bool,
        onPauseToggle: @escaping @MainActor () -> Void,
        onStop: @escaping @MainActor () -> Void
    ) {
        state.elapsedText = elapsedText
        state.isPaused = isPaused

        if panel == nil {
            let rootView = RecordingControlPanelView(
                state: state,
                onPauseToggle: onPauseToggle,
                onStop: onStop
            )
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.frame = CGRect(x: 0, y: 0, width: 292, height: 58)

            let panel = NSPanel(
                contentRect: CGRect(x: 0, y: 0, width: 292, height: 58),
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
                let x = screenFrame.midX - 146
                let y = screenFrame.maxY - 82
                panel.setFrameOrigin(CGPoint(x: x, y: y))
            }

            self.panel = panel
        }

        panel?.orderFrontRegardless()
    }

    func update(elapsedText: String, isPaused: Bool) {
        state.elapsedText = elapsedText
        state.isPaused = isPaused
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
}

private struct RecordingControlPanelView: View {
    @ObservedObject var state: RecordingControlPanelState
    let onPauseToggle: @MainActor () -> Void
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
                onStop()
            } label: {
                Image(systemName: "stop.fill")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("Stoppen")
        }
        .padding(.horizontal, 14)
        .frame(width: 292, height: 58)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}
