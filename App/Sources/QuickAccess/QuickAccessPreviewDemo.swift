#if DEBUG
import AppKit
import CaptureKit
import SharedKit
import SwiftUI

/// Both Xcode previews and the live --preview-demo use the production SwiftUI
/// views, with synthetic pixels and isolated settings. No capture or upload.
@MainActor
final class QuickAccessPreviewDemo {
    private let stack = QuickAccessStackModel()
    private var items: [QuickAccessItem] = []

    func show() {
        stack.addDemoItem = { [weak self] in self?.addItem() }
        for _ in 0..<5 { addItem() }
    }

    private func addItem() {
        guard let item = Self.makeItem(index: items.count) else { return }
        item.onClose = { [weak self, weak item] in
            guard let self, let item else { return }
            self.items.removeAll { $0 === item }
            item.close()
            self.stack.update(items: self.items)
        }
        items.append(item)
        stack.update(items: items)
    }

    static func previewStack(count: Int = 5, expanded: Bool = false) -> QuickAccessStackModel {
        let stack = QuickAccessStackModel()
        stack.loadPreviewItems((0..<count).compactMap { makeItem(index: $0) }, expanded: expanded)
        return stack
    }

    static func makeItem(index: Int) -> QuickAccessItem? {
        guard let context = CGContext(data: nil, width: 800, height: 450, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let defaults = UserDefaults(suiteName: "Capso.PreviewDemo") else { return nil }
        let colors: [NSColor] = [.systemIndigo, .systemOrange, .systemPink, .systemBlue, .systemTeal]
        context.setFillColor(colors[index % colors.count].cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 450))
        context.setFillColor(NSColor.white.withAlphaComponent(0.4).cgColor)
        context.fillEllipse(in: CGRect(x: 100 + (index % 5) * 65, y: 90, width: 260, height: 260))
        guard let image = context.makeImage() else { return nil }
        let settings = AppSettings(defaults: defaults)
        settings.quickAccessAutoClose = false
        return QuickAccessItem(result: CaptureResult(image: image, mode: .area, captureRect: CGRect(x: 0, y: 0, width: 800, height: 450)),
                               settings: settings, screen: NSScreen.main, shareCoordinator: nil, autoUpload: false)
    }
}

#Preview("Collapsed screenshots") {
    QuickAccessStackView(stack: QuickAccessPreviewDemo.previewStack())
        .environment(\.quickAccessStaticPreview, true)
        .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Scrolling screenshots") {
    QuickAccessStackView(stack: QuickAccessPreviewDemo.previewStack(count: 12, expanded: true))
        .environment(\.quickAccessStaticPreview, true)
        .background(Color(nsColor: .windowBackgroundColor))
}
#endif
