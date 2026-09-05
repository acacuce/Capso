import AppKit
import XCTest
@testable import Capso

@MainActor
final class QuickAccessStackModelTests: XCTestCase {
    func testExpandedWindowFitsTwoCardsAndResizesWhenMembershipChanges() throws {
        let stack = QuickAccessStackModel()
        defer { stack.stop() }
        var items = try (0..<2).map { try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: $0)) }
        stack.update(items: items)
        let panel = try XCTUnwrap(stack.panel)
        let bottom = panel.frame.minY
        stack.expand()
        XCTAssertEqual(stack.viewportHeight, 504)
        XCTAssertEqual(panel.frame.height, 504)
        XCTAssertEqual(panel.frame.minY, bottom, accuracy: 1)
        items.append(try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: 2)))
        stack.update(items: items)
        XCTAssertEqual(panel.frame.height, stack.viewportHeight)
        XCTAssertLessThanOrEqual(stack.viewportHeight, QuickAccessStackStyle.maximumListHeight)
        stack.update(items: Array(items.prefix(2)))
        XCTAssertEqual(panel.frame.height, 504)
    }

    func testTopPositionExpandsDownWithoutMovingFrontCard() throws {
        let stack = QuickAccessStackModel()
        defer { stack.stop() }
        stack.update(items: try (0..<2).map { try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: $0)) })
        let panel = try XCTUnwrap(stack.panel)
        let screen = try XCTUnwrap(panel.screen)
        panel.setFrameOrigin(CGPoint(x: panel.frame.minX, y: screen.visibleFrame.maxY - panel.frame.height - 16))
        let top = panel.frame.maxY
        stack.expand()
        XCTAssertFalse(stack.expandsUp)
        XCTAssertEqual(panel.frame.maxY, top, accuracy: 1)
        XCTAssertFalse(stack.hasOverflow)
        stack.update(items: try (0..<8).map { try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: $0)) })
        XCTAssertTrue(stack.hasOverflow)
    }

    func testScrollMomentumKeepsStackOpenAfterPointerLeaves() async {
        let stack = QuickAccessPreviewDemo.previewStack(count: 12)
        defer { stack.stop() }
        stack.expand()
        stack.scrollInteractionChanged(active: true)
        stack.hoverChanged(false)
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertTrue(stack.expanded)
        stack.scrollInteractionChanged(active: false)
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(stack.expanded)
    }

    func testCountIsNotCappedAtFiveAndIdentitySurvivesExpansion() throws {
        let stack = QuickAccessPreviewDemo.previewStack(count: 12)
        let identities = stack.items.map(\.id)
        XCTAssertEqual(stack.items.count, 12)
        stack.expand()
        XCTAssertTrue(stack.expanded)
        XCTAssertEqual(stack.items.map(\.id), identities)
        stack.collapse()
        XCTAssertEqual(stack.items.map(\.id), identities)
        stack.stop()
    }

    func testHoverExitIsCancellable() async {
        let stack = QuickAccessPreviewDemo.previewStack()
        defer { stack.stop() }
        stack.hoverChanged(true)
        try? await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(stack.expanded)
        stack.hoverChanged(false)
        try? await Task.sleep(for: .milliseconds(100))
        stack.hoverChanged(true)
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(stack.expanded)
        stack.hoverChanged(false)
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(stack.expanded)
    }

    func testExplicitCollapseDoesNotImmediatelyReopenUnderPointer() async {
        let stack = QuickAccessPreviewDemo.previewStack()
        defer { stack.stop() }
        stack.hoverChanged(true)
        stack.expand()
        stack.toggleExpanded()
        stack.hoverChanged(true)
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(stack.expanded)
        stack.hoverChanged(false)
        stack.hoverChanged(true)
        try? await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(stack.expanded)
    }

    func testExpandedHostKeepsBottomAnchorWhenCollapsed() async throws {
        let stack = QuickAccessStackModel()
        defer { stack.stop() }
        stack.update(items: (0..<6).compactMap { QuickAccessPreviewDemo.makeItem(index: $0) })
        let panel = try XCTUnwrap(stack.panel)
        let bottom = panel.frame.minY
        stack.expand()
        XCTAssertEqual(panel.frame.minY, bottom, accuracy: 1)
        stack.collapse()
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(panel.frame.minY, bottom, accuracy: 1)
        XCTAssertEqual(panel.frame.height, QuickAccessStackStyle.collapsedHeight, accuracy: 1)
    }

    func testAddingItemsReusesOneNativeWindow() throws {
        let stack = QuickAccessStackModel()
        defer { stack.stop() }
        var items = [try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: 0))]
        stack.update(items: items)
        let originalPanel = try XCTUnwrap(stack.panel)
        for index in 1..<12 {
            items.append(try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: index)))
            stack.update(items: items)
            XCTAssertTrue(stack.panel === originalPanel)
        }
        XCTAssertEqual(stack.items.count, 12)
        XCTAssertEqual(stack.activeItemID, items.last?.id)
        XCTAssertTrue(stack.panel?.isVisible == true)
    }
}
