import AppKit
import CaptureKit
import SharedKit
import ShareKit

/// Screenshot data and actions. This is deliberately not a window: every item
/// shares its display's SwiftUI stack host and keeps a stable identity.
@MainActor
final class QuickAccessItem: Identifiable {
    let id = UUID()
    let targetScreen: NSScreen
    let initialStackOrigin: CGPoint
    private(set) var previewView: QuickAccessView?
    weak var stackController: QuickAccessStackModel?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onAnnotate: (() -> Void)?
    var onOCR: (() -> Void)?
    var onTranslate: (() -> Void)?
    var onPin: (() -> Void)?
    var onPreview: (() -> Void)?
    var onClose: (() -> Void)?
    var onUploadSucceeded: ((String) -> Void)?
    private let settings: AppSettings
    private var dismissTask: Task<Void, Never>?
    private var interactionActive = false

    var frame: CGRect { stackController?.panel?.frame ?? CGRect(origin: initialStackOrigin, size: QuickAccessStackStyle.cardSize) }

    init(result: CaptureResult, settings: AppSettings, screen: NSScreen?, shareCoordinator: ShareCoordinator?, autoUpload: Bool) {
        self.settings = settings
        targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first!
        initialStackOrigin = QuickAccessStackGeometry.frame(position: settings.quickAccessPosition,
            screenFrame: targetScreen.frame, visibleFrame: targetScreen.visibleFrame,
            windowSize: QuickAccessStackStyle.cardSize, stackIndex: 0, stackCount: 1).origin
        // Only the thumbnail is painted while scrolling. Keep full-resolution
        // pixels for export actions, rather than decoding them on every frame.
        let thumbnailSize = QuickAccessStackStyle.thumbnailPixelSize
        let thumbnailContext = CGContext(data: nil, width: Int(thumbnailSize.width), height: Int(thumbnailSize.height),
                                         bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        let ratio = min(thumbnailSize.width / CGFloat(result.image.width), thumbnailSize.height / CGFloat(result.image.height))
        let scaledSize = CGSize(width: CGFloat(result.image.width) * ratio, height: CGFloat(result.image.height) * ratio)
        thumbnailContext?.draw(result.image, in: CGRect(origin: CGPoint(x: (thumbnailSize.width - scaledSize.width) / 2,
                                                                       y: (thumbnailSize.height - scaledSize.height) / 2), size: scaledSize))
        let nsImage = NSImage(cgImage: thumbnailContext?.makeImage() ?? result.image, size: thumbnailSize)

        let dimensions = "\(result.image.width)×\(result.image.height)"
        let targetDisplay = Locale.current.localizedString(forIdentifier: settings.translationTargetLanguage) ?? settings.translationTargetLanguage

        let view = QuickAccessView(
            thumbnail: nsImage,
            captureImage: result.image,
            dimensions: dimensions,
            capturedAt: result.timestamp,
            sourceAppName: result.appName,
            sourceWindowTitle: result.windowName,
            screenshotOutput: settings.screenshotOutputOptions,
            screenshotFilenameTemplate: settings.screenshotFilenameTemplate,
            targetLanguageDisplay: targetDisplay,
            shareCoordinator: shareCoordinator,
            autoUpload: autoUpload,
            onUploadSucceeded: { [weak self] url in self?.onUploadSucceeded?(url) },
            onCopy:      { [weak self] in self?.onCopy?() },
            onSave:      { [weak self] in self?.onSave?() },
            onAnnotate:  { [weak self] in self?.onAnnotate?() },
            onOCR:       { [weak self] in self?.onOCR?() },
            onTranslate: { [weak self] in self?.onTranslate?() },
            onPin:       { [weak self] in self?.onPin?() },
            onPreview:   { [weak self] in self?.onPreview?() },
            onDragStarted: { [weak self] in self?.stackController?.beginPanelDrag() },
            onDragEnded:   { [weak self] in self?.stackController?.endExternalDrag() },
            onClose:     { [weak self] in self?.onClose?() }
        )

        previewView = view
    }

    func activateAutoDismiss() {
        dismissTask?.cancel()
        guard settings.quickAccessAutoClose, !interactionActive else { return }
        let interval = settings.quickAccessAutoCloseInterval
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            self?.onClose?()
        }
    }

    func setStackInteractionActive(_ active: Bool) {
        guard interactionActive != active else { return }
        interactionActive = active
        if active { dismissTask?.cancel() } else { activateAutoDismiss() }
    }

    func close() { dismissTask?.cancel() }
}
