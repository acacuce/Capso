import AppKit

/// One pile per capture display. Owns layout/hover state, while CaptureCoordinator
/// continues to own screenshot actions and the existing five-preview retention cap.
@MainActor
final class QuickAccessStackController {
    private(set) var windows: [QuickAccessWindow] = [] // newest first
    private(set) var expanded = false
    private var anchor: CGPoint?
    private var pageStart = 0
    private var hoverTimer: Timer?
    private var exitTime: TimeInterval?
    private var targetFrames: [CGRect] = []
    private var dragging = false

    func update(windows: [QuickAccessWindow]) {
        self.windows = windows.reversed()
        if self.windows.isEmpty { stop(); return }
        for window in self.windows {
            window.stackController = self
        }
        if anchor == nil { anchor = self.windows[0].initialStackOrigin }
        layout(animated: true)
        startHoverTracking()
    }

    func stop() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    func expand() {
        guard !expanded, windows.count > 1 else { return }
        expanded = true
        exitTime = nil
        layout(animated: true)
    }

    func page(by delta: Int) {
        pageStart += delta
        layout(animated: true)
    }

    func beginDrag(_ window: QuickAccessWindow) {
        dragging = true
        windows.forEach {
            $0.cancelPreviewMotion()
            $0.setStackInteractionActive(true)
        }
    }

    func moveDrag(_ draggedWindow: QuickAccessWindow, to origin: CGPoint) {
        let delta = CGPoint(x: origin.x - draggedWindow.frame.minX, y: origin.y - draggedWindow.frame.minY)
        for window in windows {
            window.setFrameOrigin(CGPoint(x: window.frame.minX + delta.x, y: window.frame.minY + delta.y))
        }
    }

    func endExternalDrag() {
        dragging = false
        exitTime = nil
    }

    func endDrag(_ window: QuickAccessWindow, velocity: CGPoint) {
        dragging = false
        expanded = false
        pageStart = 0
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? window.screen ?? window.targetScreen
        anchor = QuickAccessSnapMotion.destination(frame: window.frame, visibleFrame: screen.visibleFrame, velocity: velocity)
        layout(animated: true, visibleFrame: screen.visibleFrame, releaseVelocity: velocity)
        // Don't immediately expand beneath the pointer after releasing a drag.
        exitTime = ProcessInfo.processInfo.systemUptime
    }

    func screenChanged() {
        let screen = windows.first?.screen ?? NSScreen.main
        layout(animated: true, visibleFrame: screen?.visibleFrame)
    }

    private func layout(animated: Bool, visibleFrame: CGRect? = nil, releaseVelocity: CGPoint? = nil) {
        guard let front = windows.first, let anchor else { return }
        let visible = visibleFrame ?? front.screen?.visibleFrame ?? front.targetScreen.visibleFrame
        let layout = QuickAccessStackLayout(count: windows.count, anchor: anchor, visibleFrame: visible, expanded: expanded, pageStart: pageStart)
        pageStart = layout.pageStart
        targetFrames = layout.slots.filter(\.isVisible).map(\.frame)
        // Back-to-front ordering makes the newest card the face of the pile.
        for index in windows.indices.reversed() {
            let window = windows[index]
            let slot = layout.slots[index]
            window.applyStack(slot: slot, count: windows.count, expanded: expanded,
                              isFront: index == (expanded ? pageStart : 0), pageStart: pageStart,
                              pageSize: layout.pageSize, animated: animated, velocity: releaseVelocity, visibleFrame: visible)
        }
    }

    private func startHoverTracking() {
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: QuickAccessStackStyle.hoverSampleInterval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated { self.checkHover() }
        }
        hoverTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func checkHover() {
        updateHover(at: NSEvent.mouseLocation, time: ProcessInfo.processInfo.systemUptime)
    }

    func updateHover(at pointer: CGPoint, time now: TimeInterval) {
        guard !windows.isEmpty else { stop(); return }
        guard !dragging else { return }
        let frames = targetFrames + windows.filter(\.isVisible).map(\.frame)
        guard let first = frames.first else { return }
        // One continuous corridor includes gaps and animation paths between cards.
        let corridor = frames.dropFirst().reduce(first) { $0.union($1) }
            .insetBy(dx: -QuickAccessStackStyle.hoverBridge, dy: -QuickAccessStackStyle.hoverBridge)
        if corridor.contains(pointer) {
            if !expanded, let exitTime, now - exitTime < QuickAccessStackStyle.collapseDelay { return }
            exitTime = nil
            expand()
            windows.forEach { $0.setStackInteractionActive(true) }
        } else if expanded {
            if exitTime == nil { exitTime = now }
            if let exitTime, now - exitTime >= QuickAccessStackStyle.collapseDelay {
                expanded = false
                pageStart = 0
                layout(animated: true)
                windows.forEach { $0.setStackInteractionActive(false) }
            }
        } else {
            windows.forEach { $0.setStackInteractionActive(false) }
        }
    }
}
