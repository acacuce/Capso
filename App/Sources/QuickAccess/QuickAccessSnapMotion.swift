import AppKit
import SwiftUI

/// Background-only drag surface: buttons and the file-export drag control keep
/// their own event handling.
struct QuickAccessWindowDragSurface: NSViewRepresentable {
    var onDoubleClick: (() -> Void)?
    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.onDoubleClick = onDoubleClick
        return view
    }
    func updateNSView(_ nsView: DragView, context: Context) { nsView.onDoubleClick = onDoubleClick }

    final class DragView: NSView {
        var onDoubleClick: (() -> Void)?
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2, let onDoubleClick { onDoubleClick(); return }
            guard let panel = window as? QuickAccessWindow else { return }
            panel.beginPreviewDrag()
            let start = NSEvent.mouseLocation
            let origin = panel.frame.origin
            var previous = start
            var timestamp = event.timestamp
            var velocity = CGPoint.zero
            while let next = panel.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
                let point = NSEvent.mouseLocation
                if next.type == .leftMouseUp {
                    if next.timestamp - timestamp > 0.1 { velocity = .zero }
                    panel.endPreviewDrag(velocity: velocity)
                    break
                }
                let dt = max(0.001, next.timestamp - timestamp)
                velocity = CGPoint(x: (point.x - previous.x) / dt, y: (point.y - previous.y) / dt)
                panel.setFrameOrigin(CGPoint(x: origin.x + point.x - start.x, y: origin.y + point.y - start.y))
                previous = point
                timestamp = next.timestamp
            }
        }
    }
}

@MainActor
final class QuickAccessSnapMotion {
    weak var window: NSWindow?
    private var timer: Timer?
    private var position = CGPoint.zero
    private var velocity = CGPoint.zero
    private var target = CGPoint.zero
    private var lastTime = 0.0
    private var usableFrame: CGRect?

    init(window: NSWindow) { self.window = window }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    static func destination(frame: CGRect, visibleFrame: CGRect, velocity: CGPoint) -> CGPoint {
        let bounds = visibleFrame.insetBy(dx: 16, dy: 16)
        let projected = CGPoint(x: frame.midX + velocity.x * 0.18, y: frame.midY + velocity.y * 0.18)
        return CGPoint(
            x: projected.x < bounds.midX ? bounds.minX : max(bounds.minX, bounds.maxX - frame.width),
            y: projected.y < bounds.midY ? bounds.minY : max(bounds.minY, bounds.maxY - frame.height)
        )
    }

    func snap(velocity: CGPoint = .zero, followsPointer: Bool = true) {
        guard let window else { return }
        let screen = (followsPointer ? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) : window.screen)
            ?? window.screen ?? NSScreen.main
        guard let screen else { return }
        usableFrame = screen.visibleFrame.insetBy(dx: 16, dy: 16)
        move(to: Self.destination(frame: window.frame, visibleFrame: screen.visibleFrame, velocity: velocity), velocity: velocity)
    }

    func move(to point: CGPoint, velocity newVelocity: CGPoint? = nil) {
        guard let window else { return }
        target = point
        if let newVelocity {
            velocity = CGPoint(x: min(2400, max(-2400, newVelocity.x)), y: min(2400, max(-2400, newVelocity.y)))
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            cancel()
            window.setFrameOrigin(target)
            return
        }
        guard timer == nil else { return } // Retarget the running spring without discarding momentum.
        position = window.frame.origin
        lastTime = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func step() {
        guard let window, window.isVisible else { cancel(); return }
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(1.0 / 30, now - lastTime)
        lastTime = now
        var point = position
        // Substeps keep the damped spring stable through dropped display frames.
        let steps = 4
        let h = dt / Double(steps)
        for _ in 0..<steps {
            velocity.x += ((target.x - point.x) * 320 - velocity.x * 32) * h
            velocity.y += ((target.y - point.y) * 320 - velocity.y * 32) * h
            point.x += velocity.x * h
            point.y += velocity.y * h
        }
        if let bounds = usableFrame {
            let clamped = CGPoint(x: min(max(point.x, bounds.minX), max(bounds.minX, bounds.maxX - window.frame.width)),
                                  y: min(max(point.y, bounds.minY), max(bounds.minY, bounds.maxY - window.frame.height)))
            if clamped.x != point.x { velocity.x = 0 }
            if clamped.y != point.y { velocity.y = 0 }
            point = clamped
        }
        position = point
        window.setFrameOrigin(point)
        if hypot(point.x - target.x, point.y - target.y) < 0.5 && hypot(velocity.x, velocity.y) < 4 {
            window.setFrameOrigin(target)
            velocity = .zero
            cancel()
        }
    }
}
