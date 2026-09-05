import AppKit
import XCTest
@testable import Capso

final class QuickAccessStackLayoutTests: XCTestCase {
    func testScrollDepthKeepsLowerCardsFullSizeAndUpperCardsSmaller() {
        XCTAssertEqual(QuickAccessStackStyle.scrollScale(y: 0, expanded: true), 0.86)
        XCTAssertEqual(QuickAccessStackStyle.scrollScale(y: 180, expanded: true), 1)
        XCTAssertEqual(QuickAccessStackStyle.scrollScale(y: -200, expanded: true), 0.86)
        XCTAssertEqual(QuickAccessStackStyle.scrollScale(y: 0, expanded: false), 1)
    }

    func testRetargetPreservesSpringMomentumAndEventuallyReverses() {
        var spring = QuickAccessSpring(position: .zero, target: CGPoint(x: 500, y: 0))
        for _ in 0..<8 { spring.advance(elapsed: 1 / 120) }
        let position = spring.position
        let velocity = spring.velocity
        spring.target = CGPoint(x: -100, y: 0)
        XCTAssertEqual(spring.position, position)
        XCTAssertEqual(spring.velocity, velocity)
        for _ in 0..<180 { spring.advance(elapsed: 1 / 120) }
        XCTAssertTrue(spring.isSettled)
    }

    func testSnapMarginsApplyToVisibleCardRatherThanShadowGutter() {
        let visible = CGRect(x: 0, y: 70, width: 1440, height: 800)
        let gutter = QuickAccessStackStyle.shadowGutter
        let frame = CGRect(x: 0, y: 70, width: 352, height: 292)
        let origin = QuickAccessSnapMotion.destination(frame: frame, visibleFrame: visible.insetBy(dx: -gutter, dy: -gutter), velocity: .zero)
        XCTAssertEqual(origin.x + gutter, visible.minX + QuickAccessMotionStyle.screenInset)
        XCTAssertEqual(origin.y + gutter, visible.minY + QuickAccessMotionStyle.screenInset)
    }
}
