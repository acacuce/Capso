#if DEBUG
import AppKit
import CaptureKit
import SharedKit

/// Launch with --preview-demo to exercise the real stack with generated pixels.
/// No screen capture, history entries, or uploads are involved.
@MainActor
final class QuickAccessPreviewDemo {
    private let stack = QuickAccessStackController()
    private var windows: [QuickAccessWindow] = []

    func show() {
        guard let defaults = UserDefaults(suiteName: "Capso.PreviewDemo") else { return }
        let settings = AppSettings(defaults: defaults)
        settings.quickAccessAutoClose = false
        let colors: [NSColor] = [.systemIndigo, .systemOrange, .systemPink, .systemBlue, .systemTeal]
        for (index, color) in colors.enumerated() {
            guard let image = makeImage(color: color, index: index) else { continue }
            let panel = QuickAccessWindow(
                result: CaptureResult(image: image, mode: .area, captureRect: CGRect(x: 0, y: 0, width: 800, height: 450)),
                settings: settings, screen: NSScreen.main, shareCoordinator: nil, autoUpload: false
            )
            panel.onClose = { [weak self, weak panel] in
                guard let self, let panel else { return }
                self.windows.removeAll { $0 === panel }
                panel.close()
                self.stack.update(windows: self.windows)
            }
            windows.append(panel)
            panel.show()
        }
        stack.update(windows: windows)
    }

    private func makeImage(color: NSColor, index: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: 800, height: 450, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 450))
        context.setFillColor(NSColor.white.withAlphaComponent(0.4).cgColor)
        context.fillEllipse(in: CGRect(x: 100 + index * 65, y: 90, width: 260, height: 260))
        return context.makeImage()
    }
}
#endif
