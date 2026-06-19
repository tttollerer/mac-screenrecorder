import AppKit
import SwiftUI

@MainActor
final class CountdownOverlayService {
    private let state = CountdownOverlayState()
    private var panel: NSPanel?

    func show(value: Int) {
        state.value = value

        if panel == nil {
            let rootView = CountdownOverlayView(state: state)
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.frame = CGRect(x: 0, y: 0, width: 160, height: 160)

            let panel = NSPanel(
                contentRect: CGRect(x: 0, y: 0, width: 160, height: 160),
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

            if let screenFrame = NSScreen.main?.visibleFrame {
                panel.setFrameOrigin(
                    CGPoint(
                        x: screenFrame.midX - 80,
                        y: screenFrame.midY - 80
                    )
                )
            }

            self.panel = panel
        }

        panel?.orderFrontRegardless()
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

@MainActor
private final class CountdownOverlayState: ObservableObject {
    @Published var value = 3
}

private struct CountdownOverlayView: View {
    @ObservedObject var state: CountdownOverlayState

    var body: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)

            Circle()
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)

            Text("\(state.value)")
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: 160, height: 160)
    }
}
