// App/Sources/QuickAccess/QuickAccessWindow.swift
import AppKit
import SwiftUI
import CaptureKit
import SharedKit
import ShareKit

@MainActor
final class QuickAccessWindow: NSPanel {

    override var canBecomeKey: Bool { true }

    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onAnnotate: (() -> Void)?
    var onOCR: (() -> Void)?
    var onTranslate: (() -> Void)?
    var onPin: (() -> Void)?
    var onPreview: (() -> Void)?
    var onClose: (() -> Void)?
    /// Called with the public URL string when a cloud upload succeeds.
    var onUploadSucceeded: ((String) -> Void)?

    private lazy var snapMotion = QuickAccessSnapMotion(window: self)
    weak var stackController: QuickAccessStackController?
    private let stackPresentation = QuickAccessStackPresentation()
    private var stackInteractionActive = false
    private var externalDragActive = false
    private var stackLayoutRevision = 0
    private var autoDismissTimer: Timer?
    private var alphaValueBeforeDrag: CGFloat?
    private let settings: AppSettings
    /// The screen this preview is anchored to (where the capture originated).
    let initialStackOrigin: CGPoint
    let targetScreen: NSScreen

    init(
        result: CaptureResult,
        settings: AppSettings,
        screen: NSScreen?,
        shareCoordinator: ShareCoordinator?,
        autoUpload: Bool
    ) {
        self.settings = settings
        self.targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first!

        let windowWidth = QuickAccessStackStyle.panelSize.width
        let windowHeight = QuickAccessStackStyle.panelSize.height

        let contentRect = QuickAccessStackGeometry.frame(
            position: settings.quickAccessPosition,
            screenFrame: targetScreen.frame,
            visibleFrame: targetScreen.visibleFrame,
            windowSize: CGSize(width: windowWidth, height: windowHeight),
            stackIndex: 0,
            stackCount: 1
        )

        initialStackOrigin = contentRect.origin

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isMovableByWindowBackground = false
        self.animationBehavior = .utilityWindow
        self.hidesOnDeactivate = false

        let nsImage = NSImage(cgImage: result.image, size: NSSize(
            width: result.image.width, height: result.image.height
        ))

        let dimensions = "\(result.image.width)×\(result.image.height)"
        let targetDisplay = Self.targetLanguageDisplay(settings: settings)

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
            onDragStarted: { [weak self] in self?.hideDuringExternalDrag() },
            onDragEnded:   { [weak self] in self?.showAfterExternalDrag() },
            onClose:     { [weak self] in self?.onClose?() }
        )

        let hostingView = NSHostingView(rootView: QuickAccessStackCard(content: view, presentation: stackPresentation))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.masksToBounds = false

        NotificationCenter.default.addObserver(self, selector: #selector(screenGeometryChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        self.contentView = hostingView
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private static func targetLanguageDisplay(settings: AppSettings) -> String? {
        let target = settings.translationTargetLanguage
        return Locale.current.localizedString(forIdentifier: target) ?? target
    }

    private func hideDuringExternalDrag() {
        guard alphaValueBeforeDrag == nil else { return }
        externalDragActive = true
        stackController?.beginDrag(self)
        stopAutoDismissTimer()
        alphaValueBeforeDrag = alphaValue
        alphaValue = 0
        ignoresMouseEvents = true
    }

    private func showAfterExternalDrag() {
        externalDragActive = false
        stackController?.endExternalDrag()
        alphaValue = alphaValueBeforeDrag ?? 1
        alphaValueBeforeDrag = nil
        ignoresMouseEvents = false
        scheduleAutoDismissTimerIfNeeded()
    }

    func show() {
        let finalFrame = frame
        var startFrame = finalFrame
        startFrame.origin.y += QuickAccessMotionStyle.entranceOffset
        setFrame(startFrame, display: false)
        alphaValue = 0

        orderFrontRegardless()
        makeKey()
        snapMotion.move(to: finalFrame.origin)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = QuickAccessMotionStyle.fadeInDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }

        scheduleAutoDismissTimerIfNeeded()
    }

    @objc private func screenGeometryChanged() {
        guard isVisible else { return }
        if let stackController { stackController.screenChanged() }
        else { snapMotion.snap(followsPointer: false) }
    }

    func beginPreviewDrag() {
        stackController?.beginDrag(self)
        snapMotion.cancel()
        stopAutoDismissTimer()
    }

    func cancelPreviewMotion() {
        snapMotion.cancel()
    }

    func movePreviewDrag(to origin: CGPoint) {
        if let stackController { stackController.moveDrag(self, to: origin) }
        else { setFrameOrigin(origin) }
    }

    func endPreviewDrag(velocity: CGPoint) {
        if let stackController { stackController.endDrag(self, velocity: velocity) }
        else { snapMotion.snap(velocity: velocity) }
        scheduleAutoDismissTimerIfNeeded()
    }

    override func close() {
        snapMotion.cancel()
        stopAutoDismissTimer()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = QuickAccessMotionStyle.fadeOutDuration
            self.animator().alphaValue = 0
        }, completionHandler: {
            super.close()
        })
    }

    /// Evict this preview off-screen to the left with a slide animation.
    func slideOffLeftAndClose() {
        snapMotion.cancel()
        stopAutoDismissTimer()
        var target = frame
        target.origin.x = (screen ?? targetScreen).frame.minX - target.width - QuickAccessMotionStyle.evictionMargin
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = QuickAccessMotionStyle.evictionDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().setFrame(target, display: true)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    func applyStack(slot: QuickAccessStackLayout.Slot, count: Int, expanded: Bool,
                    isFront: Bool, pageStart: Int, pageSize: Int, animated: Bool,
                    velocity: CGPoint? = nil, visibleFrame: CGRect) {
        stackLayoutRevision += 1
        let revision = stackLayoutRevision
        stackPresentation.angle = slot.angle
        stackPresentation.scale = slot.scale
        stackPresentation.count = count
        stackPresentation.expanded = expanded
        stackPresentation.isFront = isFront
        stackPresentation.pageStart = pageStart
        stackPresentation.pageSize = pageSize
        stackPresentation.onExpand = { [weak self] in self?.stackController?.expand() }
        stackPresentation.onPage = { [weak self] delta in self?.stackController?.page(by: delta) }
        ignoresMouseEvents = !expanded && !isFront
        guard slot.isVisible else {
            ignoresMouseEvents = true
            if animated && isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                snapMotion.move(to: slot.frame.origin, within: visibleFrame)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = QuickAccessStackStyle.transitionDuration
                    animator().alphaValue = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + QuickAccessStackStyle.transitionDuration) { [weak self] in
                    guard let self, self.stackLayoutRevision == revision else { return }
                    self.snapMotion.cancel()
                    self.orderOut(nil)
                }
            } else {
                snapMotion.cancel()
                orderOut(nil)
            }
            return
        }
        let shouldAnimate = animated && isVisible
        if !shouldAnimate { setFrame(slot.frame, display: true) }
        if !externalDragActive {
            alphaValue = 1
            orderFrontRegardless()
        }
        if shouldAnimate { snapMotion.move(to: slot.frame.origin, velocity: velocity, within: visibleFrame) }
    }

    func setStackInteractionActive(_ active: Bool) {
        guard stackInteractionActive != active else { return }
        stackInteractionActive = active
        if active { stopAutoDismissTimer() }
        else { scheduleAutoDismissTimerIfNeeded() }
    }

    private func scheduleAutoDismissTimerIfNeeded() {
        stopAutoDismissTimer()
        guard settings.quickAccessAutoClose, !stackInteractionActive, !externalDragActive else { return }

        autoDismissTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(settings.quickAccessAutoCloseInterval),
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onClose?()
            }
        }
    }

    private func stopAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }
}
