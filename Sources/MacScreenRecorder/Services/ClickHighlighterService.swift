import AppKit

struct ClickMarkerEvent: Sendable {
    let globalPoint: CGPoint
    let isRightClick: Bool
    let timestamp: Date
}

final class ClickMarkerStore: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [ClickMarkerEvent] = []

    func add(globalPoint: CGPoint, isRightClick: Bool) {
        lock.lock()
        events.append(ClickMarkerEvent(globalPoint: globalPoint, isRightClick: isRightClick, timestamp: Date()))
        let cutoff = Date().addingTimeInterval(-2)
        events.removeAll { $0.timestamp < cutoff }
        lock.unlock()
    }

    func events(activeAt date: Date, maxAge: TimeInterval = 0.55) -> [ClickMarkerEvent] {
        lock.lock()
        let cutoff = date.addingTimeInterval(-2)
        events.removeAll { $0.timestamp < cutoff }
        let active = events.filter { event in
            let age = date.timeIntervalSince(event.timestamp)
            return age >= 0 && age <= maxAge
        }
        lock.unlock()
        return active
    }

    func clear() {
        lock.lock()
        events = []
        lock.unlock()
    }
}

@MainActor
final class ClickHighlighterService {
    private let markerStore: ClickMarkerStore
    private var configuration = ClickHighlightConfiguration(color: .blue, size: .normal)
    private var eventMonitor: Any?
    private var windows: [ClickHighlightWindow] = []

    init(markerStore: ClickMarkerStore) {
        self.markerStore = markerStore
    }

    func start(configuration: ClickHighlightConfiguration) {
        stop()
        self.configuration = configuration
        markerStore.clear()

        windows = NSScreen.screens.map { screen in
            let window = ClickHighlightWindow(screenFrame: screen.frame, configuration: configuration)
            window.orderFrontRegardless()
            return window
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.recordAndShowClick(at: NSEvent.mouseLocation, isRightClick: event.type == .rightMouseDown)
            }
        }
    }

    func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        windows.forEach { $0.close() }
        windows = []
        markerStore.clear()
    }

    private func recordAndShowClick(at globalPoint: NSPoint, isRightClick: Bool) {
        markerStore.add(globalPoint: globalPoint, isRightClick: isRightClick)

        guard let window = windows.first(where: { $0.frame.contains(globalPoint) }) else {
            return
        }

        let localPoint = NSPoint(
            x: globalPoint.x - window.frame.minX,
            y: globalPoint.y - window.frame.minY
        )
        window.highlightView.addRipple(at: localPoint, isRightClick: isRightClick)
    }
}

final class ClickHighlightWindow: NSPanel {
    let highlightView = ClickHighlightView()

    init(screenFrame: NSRect, configuration: ClickHighlightConfiguration) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hasShadow = false
        highlightView.configuration = configuration
        contentView = highlightView
    }
}

final class ClickHighlightView: NSView {
    private struct Ripple {
        let point: NSPoint
        let isRightClick: Bool
        let startedAt: Date
    }

    private var ripples: [Ripple] = []
    private var timer: Timer?
    var configuration = ClickHighlightConfiguration(color: .blue, size: .normal)

    func addRipple(at point: NSPoint, isRightClick: Bool) {
        ripples.append(Ripple(point: point, isRightClick: isRightClick, startedAt: Date()))
        startTimerIfNeeded()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let now = Date()
        ripples.removeAll { now.timeIntervalSince($0.startedAt) > 0.55 }

        for ripple in ripples {
            let age = now.timeIntervalSince(ripple.startedAt)
            let progress = min(1, age / 0.55)
            let alpha = max(0, 1 - progress)
            let sizeScale = configuration.size.scale
            let radius = (14 + progress * 38) * sizeScale
            let rect = NSRect(
                x: ripple.point.x - radius,
                y: ripple.point.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            let color = ripple.isRightClick
                ? NSColor.systemOrange.withAlphaComponent(alpha * 0.85)
                : configuration.color.nsColor.withAlphaComponent(alpha * 0.85)

            color.setStroke()
            let path = NSBezierPath(ovalIn: rect)
            path.lineWidth = 5 * sizeScale
            path.stroke()

            NSColor.white.withAlphaComponent(alpha * 0.9).setStroke()
            let innerPath = NSBezierPath(ovalIn: rect.insetBy(dx: 8 * sizeScale, dy: 8 * sizeScale))
            innerPath.lineWidth = 2 * sizeScale
            innerPath.stroke()
        }
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.ripples.isEmpty {
                self.timer?.invalidate()
                self.timer = nil
            } else {
                self.needsDisplay = true
            }
        }
    }
}
