import AppKit

/// All stack presentation tuning lives here; screen placement uses the visible
/// card edge, while the transparent shadow gutter stays outside that margin.
enum QuickAccessStackStyle {
    static let cardSize = CGSize(width: 288, height: 200)
    static let thumbnailPixelSize = CGSize(width: 536, height: 284)
    static let cardCornerRadius: CGFloat = 14
    static let ambientShadowRadius: CGFloat = 10
    static let ambientShadowOffset: CGFloat = 6
    static let shadowGutter: CGFloat = 32
    static let headerHeight: CGFloat = 36
    static let listTopPadding: CGFloat = 8
    static let visibleDepth = 3
    static let layerStep: CGFloat = 8
    static let layerAngles: [Double] = [0, 1.5, -1.5]
    static let layerScaleStep: CGFloat = 0.025
    static let minimumLayerScale: CGFloat = 0.92
    static let rowSpacing: CGFloat = 12
    static let collapsedHeight = cardSize.height + headerHeight + layerStep * 2 + shadowGutter + listTopPadding
    static let maximumListHeight: CGFloat = 620
    static let minimumScrollScale: CGFloat = 0.86
    static let scrollDepthDistance: CGFloat = 180
    static let hoverDwell: TimeInterval = 0.18
    static let collapseDelay: TimeInterval = 0.35
    static let transitionDuration: TimeInterval = 0.34
    static let transitionDamping = 0.88
    static let insertionOffset: CGFloat = 20

    nonisolated static func expandedContentHeight(count: Int) -> CGFloat {
        CGFloat(count) * cardSize.height + CGFloat(max(0, count - 1)) * rowSpacing
    }

    nonisolated static func expandedViewportHeight(count: Int, visibleHeight: CGFloat) -> CGFloat {
        let contentHeight = headerHeight + listTopPadding + layerStep * 2 + expandedContentHeight(count: count) + shadowGutter
        return min(contentHeight, maximumListHeight, visibleHeight - QuickAccessMotionStyle.screenInset * 2)
    }

    nonisolated static func scrollScale(y: CGFloat, expanded: Bool) -> CGFloat {
        guard expanded else { return 1 }
        return min(1, max(minimumScrollScale, minimumScrollScale + (1 - minimumScrollScale) * max(0, y) / scrollDepthDistance))
    }
}
