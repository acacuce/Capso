import AppKit
import QuartzCore

/// Drives one window. Dragging cancels the display link; layout changes retarget the
/// same spring. No queued NSWindow animations can pull a re-grabbed card away.
@MainActor
final class QuickAccessSnapMotion {
    private weak var window: NSWindow?
    private var displayLink: CADisplayLink?
    private lazy var displayTarget = DisplayTarget(owner: self)
    private var spring = QuickAccessSpring(position: .zero, target: .zero)
    private var lastTime: TimeInterval = 0
    private var usableFrame: CGRect?

    init(window: NSWindow) { self.window = window }

    func cancel() {
        displayLink?.invalidate()
        displayLink = nil
    }

    nonisolated static func destination(frame: CGRect, visibleFrame: CGRect, velocity: CGPoint) -> CGPoint {
        let bounds = visibleFrame.insetBy(dx: QuickAccessMotionStyle.screenInset, dy: QuickAccessMotionStyle.screenInset)
        let projected = CGPoint(
            x: frame.midX + velocity.x * QuickAccessMotionStyle.flickProjectionTime,
            y: frame.midY + velocity.y * QuickAccessMotionStyle.flickProjectionTime
        )
        return CGPoint(
            x: projected.x < bounds.midX ? bounds.minX : max(bounds.minX, bounds.maxX - frame.width),
            y: projected.y < bounds.midY ? bounds.minY : max(bounds.minY, bounds.maxY - frame.height)
        )
    }

    func snap(velocity: CGPoint = .zero, followsPointer: Bool = true) {
        guard let window else { return }
        let pointerScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        guard let screen = (followsPointer ? pointerScreen : window.screen) ?? window.screen ?? NSScreen.main else { return }
        let target = Self.destination(frame: window.frame, visibleFrame: screen.visibleFrame, velocity: velocity)
        move(to: target, velocity: velocity, within: screen.visibleFrame)
    }

    func move(to point: CGPoint, velocity: CGPoint? = nil, within visibleFrame: CGRect? = nil) {
        guard let window else { return }
        usableFrame = visibleFrame?.insetBy(dx: QuickAccessMotionStyle.screenInset, dy: QuickAccessMotionStyle.screenInset)
        spring.target = point
        if let velocity {
            let limit = QuickAccessMotionStyle.maximumReleaseSpeed
            spring.velocity = CGPoint(x: min(limit, max(-limit, velocity.x)), y: min(limit, max(-limit, velocity.y)))
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            cancel()
            window.setFrameOrigin(point)
            return
        }
        guard displayLink == nil else { return }
        spring.position = window.frame.origin
        lastTime = ProcessInfo.processInfo.systemUptime
        let link = window.displayLink(target: displayTarget, selector: #selector(DisplayTarget.tick(_:)))
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    // CADisplayLink retains its target. A weak proxy keeps window teardown safe.
    @MainActor private final class DisplayTarget: NSObject {
        weak var owner: QuickAccessSnapMotion?
        init(owner: QuickAccessSnapMotion) { self.owner = owner }
        @objc func tick(_ link: CADisplayLink) {
            guard let owner else { link.invalidate(); return }
            owner.step()
        }
    }

    private func step() {
        guard let window, window.isVisible else { cancel(); return }
        let now = ProcessInfo.processInfo.systemUptime
        spring.advance(elapsed: now - lastTime)
        lastTime = now
        constrainToScreen(windowSize: window.frame.size)
        window.setFrameOrigin(spring.position)
        if spring.isSettled {
            window.setFrameOrigin(spring.target)
            spring.velocity = .zero
            cancel()
        }
    }

    private func constrainToScreen(windowSize: CGSize) {
        guard let bounds = usableFrame else { return }
        let clamped = CGPoint(
            x: min(max(spring.position.x, bounds.minX), max(bounds.minX, bounds.maxX - windowSize.width)),
            y: min(max(spring.position.y, bounds.minY), max(bounds.minY, bounds.maxY - windowSize.height))
        )
        if clamped.x != spring.position.x { spring.velocity.x = 0 }
        if clamped.y != spring.position.y { spring.velocity.y = 0 }
        spring.position = clamped
    }
}
