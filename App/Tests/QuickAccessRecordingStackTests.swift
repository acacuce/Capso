import AppKit
import SharedKit
import SwiftUI
import XCTest
@testable import Capso

@MainActor
final class QuickAccessRecordingStackTests: XCTestCase {
    func testMixedCapturesSharePanelAndRemoveOnlyCompletedRecording() throws {
        let store = QuickAccessPreviewStore()
        defer { for item in store.items { store.remove(item) } }
        let screenshot = try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: 0))
        store.insert(screenshot)
        let panel = try XCTUnwrap(store.stacks[screenshot.targetScreen.displayID]?.panel)
        let firstVideo = try makeRecording()
        let secondVideo = try makeRecording()
        store.insert(firstVideo)
        store.insert(secondVideo)
        XCTAssertEqual(store.items.count, 3)
        XCTAssertTrue(store.stacks[firstVideo.targetScreen.displayID]?.panel === panel)
        store.remove(firstVideo)
        XCTAssertEqual(store.items.map(\.id), [screenshot.id, secondVideo.id])
        XCTAssertEqual(store.stacks[screenshot.targetScreen.displayID]?.activeItemID, secondVideo.id)
    }

    func testExportRemainsVisibleWhenHoverEnds() async throws {
        let state = RecordingPreviewState()
        state.isSaving = true
        let item = try makeRecording(state: state, autoClose: true)
        defer { item.close() }
        var closed = false
        item.onClose = { closed = true }
        item.setStackInteractionActive(true)
        item.setStackInteractionActive(false)
        item.activateAutoDismiss()
        try? await Task.sleep(for: .milliseconds(1150))
        XCTAssertFalse(closed)
    }

    func testRecordingCardsRenderInIdleAndSavingStates() throws {
        let state = RecordingPreviewState()
        let item = try makeRecording(state: state)
        let view = try XCTUnwrap(item.recordingView)
        for saving in [false, true] {
            state.isSaving = saving
            state.saveProgress = 0.42
            let renderer = ImageRenderer(content: view.modifier(QuickAccessCardShadow()).padding(32))
            renderer.scale = 2
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: "/private/tmp/capso-recording-\(saving ? "saving" : "idle").png"))
            XCTAssertEqual(bitmap.pixelsWide, 704)
            XCTAssertEqual(bitmap.pixelsHigh, 528)
        }
    }

    private func makeRecording(state: RecordingPreviewState = RecordingPreviewState(), autoClose: Bool = false) throws -> QuickAccessItem {
        let suite = "Capso.RecordingStackTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.quickAccessAutoClose = autoClose
        settings.quickAccessAutoCloseInterval = 1
        return QuickAccessItem(thumbnail: nil, duration: "00:13", fileSize: "2.4 MB",
                               state: state, settings: settings, screen: NSScreen.main)
    }
}
