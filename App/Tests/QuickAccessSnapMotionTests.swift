import AppKit
import XCTest
@testable import Capso

@MainActor
final class QuickAccessSnapMotionTests: XCTestCase {
    func testCornersRespectDockAndMenuBarOnOffsetDisplay() {
        let visible = CGRect(x: -1440, y: 80, width: 1440, height: 790)
        for x in [-1400.0, -350.0] {
            for y in [100.0, 600.0] {
                let frame = CGRect(x: x, y: y, width: 288, height: 200)
                let origin = QuickAccessSnapMotion.destination(frame: frame, visibleFrame: visible, velocity: .zero)
                XCTAssertTrue(visible.insetBy(dx: 16, dy: 16).contains(CGRect(origin: origin, size: frame.size)))
            }
        }
    }

    func testRunningSpringCanReverseAndCancelWithoutJumping() {
        let window = NSPanel(contentRect: CGRect(x: 300, y: 300, width: 288, height: 200), styleMask: [.borderless], backing: .buffered, defer: false)
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let motion = QuickAccessSnapMotion(window: window)
        motion.move(to: CGPoint(x: 900, y: 300))
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        let before = window.frame.origin
        motion.move(to: CGPoint(x: 100, y: 300))
        XCTAssertEqual(window.frame.origin, before)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertEqual(window.frame.minX, 100, accuracy: 1)
        motion.cancel()
        let stopped = window.frame.origin
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(window.frame.origin, stopped)
    }

    func testFlickAndReversalSelectOppositeCorners() {
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 840)
        let frame = CGRect(x: 576, y: 360, width: 288, height: 200)
        let right = QuickAccessSnapMotion.destination(frame: frame, visibleFrame: visible, velocity: CGPoint(x: 1000, y: 0))
        let left = QuickAccessSnapMotion.destination(frame: frame, visibleFrame: visible, velocity: CGPoint(x: -1000, y: 0))
        XCTAssertEqual(right.x, 1136)
        XCTAssertEqual(left.x, 16)
    }
}
