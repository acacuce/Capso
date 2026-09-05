#if DEBUG
import AppKit
import CaptureKit
import SharedKit

/// Explicit developer launch mode; uses synthetic pixels and isolated preferences.
@MainActor
enum QuickAccessPreviewDemo {
    static func makeWindow() -> QuickAccessWindow? {
        guard let context = CGContext(data: nil, width: 800, height: 450, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(NSColor.systemIndigo.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 450))
        context.setFillColor(NSColor.systemTeal.cgColor)
        context.fillEllipse(in: CGRect(x: 280, y: 90, width: 260, height: 260))
        guard let image = context.makeImage(), let defaults = UserDefaults(suiteName: "Capso.PreviewDemo") else { return nil }
        let settings = AppSettings(defaults: defaults)
        settings.quickAccessAutoClose = false
        let panel = QuickAccessWindow(result: CaptureResult(image: image, mode: .area, captureRect: CGRect(x: 0, y: 0, width: 800, height: 450)),
                                      settings: settings, screen: NSScreen.main, shareCoordinator: nil, autoUpload: false)
        panel.onClose = { [weak panel] in panel?.close() }
        return panel
    }
}
#endif
