import AppKit

/// Presentation policy, independent of window lifetime and hover events.
enum QuickAccessStackStyle {
    static let cardSize = CGSize(width: 288, height: 200)
    // Room for tilted corners and shadows; rotations never clip at a panel edge.
    static let rotationPadding: CGFloat = 24
    static let panelSize = CGSize(width: cardSize.width + rotationPadding * 2, height: cardSize.height + rotationPadding * 2)
    static let visibleDepth = 3
    static let layerOffset: CGFloat = 9
    static let layerScaleStep: CGFloat = 0.035
    static let layerAngles: [Double] = [0, 7, -6]
    static let rowGap: CGFloat = 4
    static let hoverBridge: CGFloat = 8
    static let hoverSampleInterval: TimeInterval = 0.06
    static let collapseDelay: TimeInterval = 0.35
    static let transitionDamping = 0.86
    static let transitionDuration: TimeInterval = 0.32
}

struct QuickAccessStackLayout {
    struct Slot {
        let frame: CGRect
        let angle: Double
        let scale: CGFloat
        let isVisible: Bool
    }
    let slots: [Slot] // newest first
    let pageSize: Int
    let pageStart: Int

    init(count: Int, anchor: CGPoint, visibleFrame: CGRect, expanded: Bool, pageStart: Int = 0) {
        let size = QuickAccessStackStyle.panelSize
        let bounds = visibleFrame.insetBy(dx: QuickAccessMotionStyle.screenInset, dy: QuickAccessMotionStyle.screenInset)
        let step = size.height + QuickAccessStackStyle.rowGap
        let capacity = max(1, Int((bounds.height + QuickAccessStackStyle.rowGap) / step))
        self.pageSize = min(count, capacity)
        self.pageStart = min(max(0, pageStart), max(0, count - capacity))
        let rows = expanded ? self.pageSize : min(count, QuickAccessStackStyle.visibleDepth)
        let extent = expanded ? CGFloat(max(0, rows - 1)) * step : CGFloat(max(0, rows - 1)) * QuickAccessStackStyle.layerOffset
        let growsUp = anchor.y + size.height / 2 < bounds.midY
        let x = min(max(anchor.x, bounds.minX), max(bounds.minX, bounds.maxX - size.width))
        let baseY = growsUp
            ? min(max(anchor.y, bounds.minY), max(bounds.minY, bounds.maxY - size.height - extent))
            : max(min(anchor.y, bounds.maxY - size.height), bounds.minY + extent)
        let firstVisible = self.pageStart
        let visibleCount = self.pageSize
        self.slots = (0..<count).map { index in
            let row = expanded ? index - firstVisible : min(index, QuickAccessStackStyle.visibleDepth - 1)
            let distance = CGFloat(row) * (expanded ? step : QuickAccessStackStyle.layerOffset)
            let visible = expanded ? (row >= 0 && row < visibleCount) : index < QuickAccessStackStyle.visibleDepth
            return Slot(
                frame: CGRect(origin: CGPoint(x: x, y: baseY + (growsUp ? distance : -distance)), size: size),
                angle: expanded ? 0 : QuickAccessStackStyle.layerAngles[min(index, QuickAccessStackStyle.visibleDepth - 1)],
                scale: expanded ? 1 : 1 - CGFloat(min(index, QuickAccessStackStyle.visibleDepth - 1)) * QuickAccessStackStyle.layerScaleStep,
                isVisible: visible
            )
        }
    }
}
