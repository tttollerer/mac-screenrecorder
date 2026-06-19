import AppKit
import CoreGraphics

@MainActor
final class RegionSelectionService {
    private var panel: RegionSelectionPanel?
    private var continuation: CheckedContinuation<CGRect?, Never>?

    func selectRegion(on screen: NSScreen) async -> CGRect? {
        cancel()

        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            let panel = RegionSelectionPanel(screen: screen) { [weak self] rect in
                self?.finish(with: rect)
            }
            self.panel = panel
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func cancel() {
        panel?.close()
        panel = nil
        continuation?.resume(returning: nil)
        continuation = nil
    }

    private func finish(with rect: CGRect?) {
        panel?.close()
        panel = nil
        continuation?.resume(returning: rect)
        continuation = nil
    }
}

private final class RegionSelectionPanel: NSPanel {
    init(screen: NSScreen, completion: @escaping (CGRect?) -> Void) {
        let selectionView = RegionSelectionView(screenFrame: screen.frame, completion: completion)

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = selectionView
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
}

private final class RegionSelectionView: NSView {
    private let screenFrame: CGRect
    private let completion: (CGRect?) -> Void
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?

    init(screenFrame: CGRect, completion: @escaping (CGRect?) -> Void) {
        self.screenFrame = screenFrame
        self.completion = completion
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            completion(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStart = point
        dragCurrent = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        dragCurrent = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragCurrent = convert(event.locationInWindow, from: nil)

        guard let selectionRect, selectionRect.width >= 40, selectionRect.height >= 40 else {
            completion(nil)
            return
        }

        let globalRect = CGRect(
            x: screenFrame.minX + selectionRect.minX,
            y: screenFrame.minY + selectionRect.minY,
            width: selectionRect.width,
            height: selectionRect.height
        )

        completion(globalRect)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.36).setFill()
        bounds.fill()

        if let selectionRect {
            NSColor.clear.setFill()
            selectionRect.fill(using: .clear)

            NSColor.systemBlue.withAlphaComponent(0.22).setFill()
            selectionRect.fill()

            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
            path.lineWidth = 3
            path.stroke()

            drawSizeLabel(for: selectionRect)
        } else {
            drawInstruction()
        }
    }

    private var selectionRect: CGRect? {
        guard let dragStart, let dragCurrent else { return nil }
        return CGRect(
            x: min(dragStart.x, dragCurrent.x),
            y: min(dragStart.y, dragCurrent.y),
            width: abs(dragStart.x - dragCurrent.x),
            height: abs(dragStart.y - dragCurrent.y)
        )
    }

    private func drawInstruction() {
        let text = "Bereich ziehen - Esc zum Abbrechen"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let rect = CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        text.draw(in: rect, withAttributes: attributes)
    }

    private func drawSizeLabel(for rect: CGRect) {
        let text = "\(Int(rect.width)) x \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let backgroundRect = CGRect(
            x: rect.minX,
            y: max(8, rect.minY - textSize.height - 16),
            width: textSize.width + 18,
            height: textSize.height + 10
        )
        NSColor.black.withAlphaComponent(0.62).setFill()
        NSBezierPath(roundedRect: backgroundRect, xRadius: 5, yRadius: 5).fill()
        text.draw(
            in: backgroundRect.insetBy(dx: 9, dy: 5),
            withAttributes: attributes
        )
    }
}
