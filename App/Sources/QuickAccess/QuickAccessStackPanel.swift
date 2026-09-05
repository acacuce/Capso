import AppKit
import SwiftUI

@MainActor
final class QuickAccessStackPanel: NSPanel {
    private weak var stack: QuickAccessStackModel?
    private var anchoredAtTop = false
    private lazy var motion = QuickAccessSnapMotion(window: self)
    override var canBecomeKey: Bool { true }

    init(controller: QuickAccessStackModel, screen: NSScreen, initialOrigin: CGPoint) {
        stack = controller
        let gutter = QuickAccessStackStyle.shadowGutter
        let size = CGSize(width: QuickAccessStackStyle.cardSize.width + gutter * 2,
                          height: QuickAccessStackStyle.collapsedHeight)
        let onRight = initialOrigin.x > screen.visibleFrame.midX
        let x = onRight ? screen.visibleFrame.maxX - QuickAccessMotionStyle.screenInset - size.width + gutter
                        : screen.visibleFrame.minX + QuickAccessMotionStyle.screenInset - gutter
        let y = screen.visibleFrame.minY + QuickAccessMotionStyle.screenInset - gutter
        super.init(contentRect: CGRect(origin: CGPoint(x: x, y: y), size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        contentView = NSHostingView(rootView: QuickAccessStackView(stack: controller).environment(\.quickAccessWindow, self))
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    func resizeViewport(to height: CGFloat) {
        let gutter = QuickAccessStackStyle.shadowGutter
        var next = frame
        let newHeight = height
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? frame
        if stack?.expandsUp == false { next.origin.y += next.height - newHeight }
        next.size.height = newHeight
        next.origin.y = max(visible.minY + QuickAccessMotionStyle.screenInset - gutter,
                            min(next.origin.y, visible.maxY - QuickAccessMotionStyle.screenInset - newHeight))
        motion.cancel()
        setFrame(next, display: true)
    }

    func cancelMotion() { motion.cancel() }
    func snap(velocity: CGPoint) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? screen ?? NSScreen.main else { return }
        let gutter = QuickAccessStackStyle.shadowGutter
        // Only the visible card gets a margin; the transparent blur gutter may
        // extend beyond the usable screen without pushing the card inward.
        let bounds = CGRect(x: screen.visibleFrame.minX - gutter, y: screen.visibleFrame.minY - gutter,
                            width: screen.visibleFrame.width + gutter * 2, height: screen.visibleFrame.height + gutter)
        let target = QuickAccessSnapMotion.destination(frame: frame, visibleFrame: bounds, velocity: velocity)
        anchoredAtTop = target.y + frame.height / 2 > screen.visibleFrame.midY
        motion.move(to: target, velocity: velocity, within: bounds)
    }

    func beginPreviewDrag() { stack?.beginPanelDrag() }
    func movePreviewDrag(to origin: CGPoint) { setFrameOrigin(origin) }
    func endPreviewDrag(velocity: CGPoint) { stack?.endPanelDrag(velocity: velocity) }
    @objc private func screenChanged() { snap(velocity: .zero) }
}
