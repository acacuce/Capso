import AppKit
import XCTest
@testable import Capso

final class QuickAccessStackLayoutTests: XCTestCase {
    private let visible = CGRect(x: -1440, y: 80, width: 1440, height: 790)

    func testCollapsedDepthIsCappedAndAlternatesAngles() {
        let layout = QuickAccessStackLayout(count: 5, anchor: CGPoint(x: -1400, y: 100), visibleFrame: visible, expanded: false)
        XCTAssertEqual(layout.slots.filter(\.isVisible).count, 3)
        XCTAssertEqual(layout.slots.map(\.angle).prefix(3), [0, 7, -6])
        XCTAssertEqual(layout.slots[0].scale, 1)
        XCTAssertGreaterThan(layout.slots[1].scale, layout.slots[2].scale)
    }

    func testExpandedRowsDoNotOverlapAndStayInsideUsableScreenAtEveryCorner() {
        for x in [-1440.0, -336.0] {
            for y in [80.0, 622.0] {
                let layout = QuickAccessStackLayout(count: 5, anchor: CGPoint(x: x, y: y), visibleFrame: visible, expanded: true)
                let rows = layout.slots.filter(\.isVisible)
                for row in rows {
                    XCTAssertTrue(visible.contains(row.frame))
                    XCTAssertEqual(row.angle, 0)
                    XCTAssertEqual(row.scale, 1)
                }
                for pair in zip(rows, rows.dropFirst()) {
                    XCTAssertFalse(pair.0.frame.intersects(pair.1.frame))
                }
            }
        }
    }

    func testPagingReachesEveryRetainedScreenshotWithoutShrinkingControls() {
        var reached = Set<Int>()
        for page in 0..<5 {
            let layout = QuickAccessStackLayout(count: 5, anchor: visible.origin, visibleFrame: visible, expanded: true, pageStart: page)
            for (index, slot) in layout.slots.enumerated() where slot.isVisible {
                reached.insert(index)
                XCTAssertEqual(slot.frame.size, QuickAccessStackStyle.panelSize)
            }
        }
        XCTAssertEqual(reached, Set(0..<5))
    }

    func testDeletingItemsClampsPageToRemainingMembers() {
        let layout = QuickAccessStackLayout(count: 1, anchor: visible.origin, visibleFrame: visible, expanded: true, pageStart: 4)
        XCTAssertEqual(layout.pageStart, 0)
        XCTAssertTrue(layout.slots[0].isVisible)
    }

    func testRetargetPreservesSpringMomentumAndEventuallyReverses() {
        var spring = QuickAccessSpring(position: .zero, target: CGPoint(x: 500, y: 0))
        for _ in 0..<8 { spring.advance(elapsed: 1 / 120) }
        let previousPosition = spring.position
        let previousVelocity = spring.velocity
        spring.target = CGPoint(x: -100, y: 0)
        XCTAssertEqual(spring.position, previousPosition)
        XCTAssertEqual(spring.velocity, previousVelocity)
        for _ in 0..<180 { spring.advance(elapsed: 1 / 120) }
        XCTAssertTrue(spring.isSettled)
        XCTAssertEqual(spring.position.x, -100, accuracy: 0.5)
    }
}
