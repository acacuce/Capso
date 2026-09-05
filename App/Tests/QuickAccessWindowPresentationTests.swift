import AppKit
import CaptureKit
import SharedKit
import XCTest
@testable import Capso

@MainActor
final class QuickAccessWindowPresentationTests: XCTestCase {
    func testSingleHostUsesNonactivatingCrossSpaceConfiguration() throws {
        let stack = QuickAccessStackModel()
        defer { stack.stop() }
        stack.update(items: [try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: 0))])
        let window = try XCTUnwrap(stack.panel)
        XCTAssertTrue(window.styleMask.contains(.nonactivatingPanel))
        XCTAssertEqual(window.level, .floating)
        XCTAssertFalse(window.hidesOnDeactivate)
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(window.isVisible)
    }

    func testAutoDismissIsPausedDuringInteraction() async throws {
        let suite = "QuickAccessAutoDismissTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.quickAccessAutoClose = true
        settings.quickAccessAutoCloseInterval = 1
        let image = try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: 0)?.previewView?.captureImage)
        let item = QuickAccessItem(result: CaptureResult(image: image, mode: .area, captureRect: .zero), settings: settings,
                                   screen: NSScreen.main, shareCoordinator: nil, autoUpload: false)
        var closes = 0
        item.onClose = { closes += 1 }
        item.activateAutoDismiss()
        item.setStackInteractionActive(true)
        try? await Task.sleep(for: .milliseconds(1100))
        XCTAssertEqual(closes, 0)
        item.setStackInteractionActive(false)
        try? await Task.sleep(for: .milliseconds(1100))
        XCTAssertEqual(closes, 1)
    }
}

@MainActor
final class HistoryWindowShortcutToggleTests: XCTestCase {
    func testToggleShowsHidesAndShowsTheSameHistoryWindow() throws {
        let suiteName = "HistoryWindowShortcutToggleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let coordinator = HistoryCoordinator(settings: AppSettings(defaults: defaults))
        defer {
            if coordinator.isWindowVisibleForTesting {
                coordinator.toggleWindow()
            }
            defaults.removePersistentDomain(forName: suiteName)
        }

        coordinator.toggleWindow()
        XCTAssertTrue(coordinator.isWindowVisibleForTesting)

        coordinator.toggleWindow()
        XCTAssertFalse(coordinator.isWindowVisibleForTesting)

        coordinator.toggleWindow()
        XCTAssertTrue(coordinator.isWindowVisibleForTesting)
    }
}
