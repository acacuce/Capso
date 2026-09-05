import AppKit
import SwiftUI

extension EnvironmentValues {
    @Entry var quickAccessWindow: QuickAccessStackPanel? = nil
}

/// SwiftUI owns gesture recognition/cancellation. Screen-space samples avoid
/// feedback from the window moving beneath the pointer during a drag.
struct QuickAccessWindowDragSurface: View {
    var onDoubleClick: (() -> Void)?
    @Environment(\.quickAccessWindow) private var window
    @GestureState private var gestureActive = false
    @State private var drag: WindowDragSample?

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3)
                    .updating($gestureActive) { _, active, _ in active = true }
                    .onChanged { _ in updateDrag() }
                    .onEnded { _ in finishDrag() }
            )
            .onTapGesture(count: 2) { onDoubleClick?() }
            .onChange(of: gestureActive) { _, active in
                if !active { finishDrag() }
            }
    }

    private func updateDrag() {
        guard let window else { return }
        let point = NSEvent.mouseLocation
        let now = ProcessInfo.processInfo.systemUptime
        if drag == nil {
            window.beginPreviewDrag()
            drag = WindowDragSample(pointer: point, origin: window.frame.origin, time: now)
        }
        guard var sample = drag else { return }
        sample.update(pointer: point, time: now)
        window.movePreviewDrag(to: sample.windowOrigin)
        drag = sample
    }

    private func finishDrag() {
        guard let sample = drag else { return }
        drag = nil
        let paused = ProcessInfo.processInfo.systemUptime - sample.time > QuickAccessMotionStyle.releasePause
        window?.endPreviewDrag(velocity: paused ? .zero : sample.velocity)
    }
}

private struct WindowDragSample {
    let initialPointer: CGPoint
    let initialOrigin: CGPoint
    var pointer: CGPoint
    var time: TimeInterval
    var velocity = CGPoint.zero

    init(pointer: CGPoint, origin: CGPoint, time: TimeInterval) {
        initialPointer = pointer
        initialOrigin = origin
        self.pointer = pointer
        self.time = time
    }

    var windowOrigin: CGPoint {
        CGPoint(x: initialOrigin.x + pointer.x - initialPointer.x, y: initialOrigin.y + pointer.y - initialPointer.y)
    }

    mutating func update(pointer: CGPoint, time: TimeInterval) {
        let dt = max(QuickAccessMotionStyle.minimumDragSampleTime, time - self.time)
        velocity = CGPoint(x: (pointer.x - self.pointer.x) / dt, y: (pointer.y - self.pointer.y) / dt)
        self.pointer = pointer
        self.time = time
    }
}
