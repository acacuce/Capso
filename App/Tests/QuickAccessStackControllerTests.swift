import AppKit
import CaptureKit
import SharedKit
import XCTest
@testable import Capso

@MainActor
final class QuickAccessStackControllerTests: XCTestCase {
    func testHoverExpandsAndExitDelayCanBeCancelled() throws {
        let (stack, windows) = try makeStack()
        defer { stack.stop(); windows.forEach { $0.orderOut(nil) } }
        let point = CGPoint(x: windows.last!.frame.midX, y: windows.last!.frame.midY)
        stack.updateHover(at: point, time: 1)
        XCTAssertTrue(stack.expanded)
        let outside = CGPoint(x: -100_000, y: -100_000)
        stack.updateHover(at: outside, time: 2)
        stack.updateHover(at: outside, time: 2.1)
        XCTAssertTrue(stack.expanded)
        stack.updateHover(at: point, time: 2.2)
        stack.updateHover(at: outside, time: 3)
        XCTAssertTrue(stack.expanded)
        stack.updateHover(at: outside, time: 3.5)
        XCTAssertFalse(stack.expanded)
        stack.updateHover(at: point, time: 4)
        XCTAssertTrue(stack.expanded)
    }

    func testNewestCardIsFrontAndRemovalUpdatesMembership() throws {
        let (stack, windows) = try makeStack()
        defer { stack.stop(); windows.forEach { $0.orderOut(nil) } }
        XCTAssertTrue(stack.windows.first === windows.last)
        stack.expand()
        stack.page(by: 99)
        stack.update(windows: Array(windows.prefix(1)))
        XCTAssertEqual(stack.windows.count, 1)
        XCTAssertTrue(windows[0].isVisible)
        XCTAssertFalse(windows[0].ignoresMouseEvents)
    }

    func testDraggingMovesEveryCardByTheSameDelta() throws {
        let (stack, windows) = try makeStack()
        defer { stack.stop(); windows.forEach { $0.orderOut(nil) } }
        let original = windows.map(\.frame.origin)
        let front = try XCTUnwrap(windows.last)
        stack.beginDrag(front)
        stack.moveDrag(front, to: CGPoint(x: front.frame.minX + 100, y: front.frame.minY + 80))
        for (window, origin) in zip(windows, original) {
            XCTAssertEqual(window.frame.minX, origin.x + 100, accuracy: 1)
            XCTAssertEqual(window.frame.minY, origin.y + 80, accuracy: 1)
        }
    }

    private func makeStack() throws -> (QuickAccessStackController, [QuickAccessWindow]) {
        let context = try XCTUnwrap(CGContext(data: nil, width: 8, height: 6, bitsPerComponent: 8, bytesPerRow: 32,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let suite = "QuickAccessStackTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.quickAccessAutoClose = false
        let windows = (0..<5).map { _ in
            QuickAccessWindow(result: CaptureResult(image: image, mode: .area, captureRect: CGRect(x: 0, y: 0, width: 8, height: 6)),
                              settings: settings, screen: NSScreen.main, shareCoordinator: nil, autoUpload: false)
        }
        let stack = QuickAccessStackController()
        stack.update(windows: windows)
        stack.stop() // Drive hover time explicitly rather than depending on the user's mouse.
        return (stack, windows)
    }
}
