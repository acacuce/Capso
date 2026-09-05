import SwiftUI

/// The same stable card identities live in one scrolling hierarchy. Collapsing
/// only changes their geometry; upload/action state isn't recreated on hover.
struct QuickAccessStackView: View {
    let stack: QuickAccessStackModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scrollAnchor: UnitPoint { stack.expandsUp ? .bottom : .top }

    var body: some View {
        ScrollView(.vertical) {
            QuickAccessCardsLayout(expansion: stack.expanded ? 1 : 0, expandsUp: stack.expandsUp) {
                header
                ForEach(Array(stack.items.enumerated()), id: \.element.id) { index, entry in
                    QuickAccessStackRow(entry: entry, index: index, count: stack.items.count,
                                        expanded: stack.expanded, selected: stack.activeItemID == entry.id,
                                        showsOverflowCue: stack.expanded && index == 0 && !entry.isRecording && stack.hasOverflow)
                        .onHover { inside in
                            if inside { stack.activeItemID = entry.id }
                            stack.cardHoverChanged(id: entry.id, inside: inside)
                        }
                        .id(entry.id)
                }
            }
            .frame(width: QuickAccessStackStyle.cardSize.width)
            .padding(.horizontal, QuickAccessStackStyle.shadowGutter)
            .padding(.bottom, QuickAccessStackStyle.shadowGutter)
        }
        .scrollIndicators(.never)
        .scrollDisabled(!stack.expanded)
        .defaultScrollAnchor(scrollAnchor)
        .defaultScrollAnchor(scrollAnchor, for: .sizeChanges)
        .frame(height: stack.expanded ? stack.viewportHeight : QuickAccessStackStyle.collapsedHeight)
        .frame(height: stack.viewportHeight, alignment: stack.expandsUp ? .bottom : .top)
    }

    private var header: some View {
        HStack {
            Label("\(stack.items.count) captures", systemImage: "square.on.square")
                .font(.system(size: 12, weight: .medium))
                .contentTransition(.numericText())
            Spacer()
            #if DEBUG
            if let add = stack.addDemoItem {
                Button(action: add) { Image(systemName: "plus") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add demo screenshot")
            }
            #endif
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(width: QuickAccessStackStyle.cardSize.width, height: QuickAccessStackStyle.headerHeight)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .background { QuickAccessWindowDragSurface() }
        .help("Drag to move captures")
    }
}

struct QuickAccessCardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: QuickAccessStackStyle.cardCornerRadius, style: .continuous)
                .fill(.black.opacity(0.16))
                .blur(radius: QuickAccessStackStyle.ambientShadowRadius)
                .offset(y: QuickAccessStackStyle.ambientShadowOffset)
        }
    }
}

private struct QuickAccessStackRow: View {
    let entry: QuickAccessItem
    let index: Int
    let count: Int
    let expanded: Bool
    let selected: Bool
    let showsOverflowCue: Bool

    var body: some View {
        content
                .frame(width: QuickAccessStackStyle.cardSize.width, height: QuickAccessStackStyle.cardSize.height)
                .modifier(QuickAccessCardShadow())
                .scaleEffect(expanded ? 1 : max(QuickAccessStackStyle.minimumLayerScale, 1 - CGFloat(index) * QuickAccessStackStyle.layerScaleStep), anchor: .bottom)
                .rotationEffect(.degrees(expanded || index == 0 ? 0 : QuickAccessStackStyle.layerAngles[min(index, QuickAccessStackStyle.visibleDepth - 1)]))
                .opacity(expanded || index < QuickAccessStackStyle.visibleDepth ? 1 : 0)
                .allowsHitTesting(expanded || index == 0)
                .accessibilityHidden(!expanded && index != 0)
                .zIndex(Double(count - index))
                .scaleEffect(showsOverflowCue ? QuickAccessStackStyle.minimumScrollScale : 1, anchor: .bottom)
                .transition(.asymmetric(insertion: .offset(y: QuickAccessStackStyle.insertionOffset).combined(with: .opacity), removal: .opacity))
    }

    @ViewBuilder
    private var content: some View {
        if let screenshot = entry.previewView {
            screenshot.keyboardActionsEnabled(selected)
        } else if let recording = entry.recordingView {
            recording
        }
    }

}
// Layout positions participate in ScrollView geometry and clipping. Visual
// offsets alone leave every row occupying the same bottom-most layout slot.
struct QuickAccessCardsLayout: Layout {
    var expansion: CGFloat
    var expandsUp: Bool
    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let style = QuickAccessStackStyle.self
        let collapsed = style.collapsedHeight - style.shadowGutter
        let expanded = style.expandedContentHeight(count: max(0, subviews.count - 1))
            + style.headerHeight + style.listTopPadding + style.layerStep * 2
        return CGSize(width: style.cardSize.width, height: collapsed + (expanded - collapsed) * expansion)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let header = subviews.first else { return }
        let style = QuickAccessStackStyle.self
        let headerGap = style.headerHeight + style.listTopPadding
        let collapsedTop = headerGap + style.layerStep * 2
        let frontY = expandsUp ? bounds.maxY - style.cardSize.height : bounds.minY + collapsedTop
        header.place(at: CGPoint(x: bounds.midX, y: frontY - headerGap), anchor: .top,
                     proposal: ProposedViewSize(width: style.cardSize.width, height: style.headerHeight))
        for (index, subview) in subviews.dropFirst().enumerated() {
            let collapsedOffset = -CGFloat(min(index, style.visibleDepth - 1)) * style.layerStep
            let distance = CGFloat(index) * (style.cardSize.height + style.rowSpacing)
            let expandedOffset = expandsUp ? -distance - (index > 0 ? headerGap : 0) : distance
            let offset = collapsedOffset + (expandedOffset - collapsedOffset) * expansion
            subview.place(at: CGPoint(x: bounds.midX, y: frontY + offset), anchor: .top,
                          proposal: ProposedViewSize(style.cardSize))
        }
    }
}
