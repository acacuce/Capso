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
                    if next.timestamp - timestamp > QuickAccessMotionStyle.releasePause { velocity = .zero }
                    panel.endPreviewDrag(velocity: velocity)
                    break
                }
                let dt = max(QuickAccessMotionStyle.minimumDragSampleTime, next.timestamp - timestamp)
                velocity = CGPoint(x: (point.x - previous.x) / dt, y: (point.y - previous.y) / dt)
                panel.movePreviewDrag(to: CGPoint(x: origin.x + point.x - start.x, y: origin.y + point.y - start.y))
                previous = point
                timestamp = next.timestamp
            }
        }
    }
}

