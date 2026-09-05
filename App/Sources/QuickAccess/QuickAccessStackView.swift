import SwiftUI

/// The same stable card identities live in one scrolling hierarchy. Collapsing
/// only changes their geometry; upload/action state isn't recreated on hover.
struct QuickAccessStackView: View {
    let stack: QuickAccessStackModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cardHeight: CGFloat { QuickAccessStackStyle.cardSize.height }
    private var listHeight: CGFloat {
        stack.expanded ? CGFloat(stack.items.count) * (cardHeight + QuickAccessStackStyle.rowSpacing)
            : cardHeight + QuickAccessStackStyle.layerStep * 2
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { scroll in
                ScrollView(.vertical) {
                    ZStack(alignment: .bottom) {
                        Color.clear.frame(width: 1, height: 1).id("latestAnchor")
                        ForEach(Array(stack.items.enumerated()), id: \.element.id) { index, entry in
                            QuickAccessStackRow(entry: entry, index: index, count: stack.items.count,
                                                expanded: stack.expanded, selected: stack.activeItemID == entry.id)
                                .onHover { if $0 { stack.activeItemID = entry.id } }
                                .id(entry.id)
                        }
                    }
                    .frame(width: QuickAccessStackStyle.cardSize.width, height: listHeight, alignment: .bottom)
                    .padding(.horizontal, QuickAccessStackStyle.shadowGutter)
                    .padding(.top, QuickAccessStackStyle.listTopPadding)
                    .padding(.bottom, QuickAccessStackStyle.shadowGutter)
                }
                .scrollIndicators(stack.expanded ? .automatic : .hidden)
                .scrollDisabled(!stack.expanded)
                .defaultScrollAnchor(.bottom)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .onChange(of: stack.items.first?.id) { _, id in
                    if id != nil { withAnimation(stack.animation) { scroll.scrollTo("latestAnchor", anchor: .bottom) } }
                }
                .onChange(of: stack.expanded) { _, _ in
                    Task { @MainActor in
                        await Task.yield()
                        scroll.scrollTo("latestAnchor", anchor: .bottom)
                    }
                }
            }
        }
        .frame(height: stack.expanded ? stack.viewportHeight : QuickAccessStackStyle.collapsedHeight)
        .contentShape(Rectangle())
        .onHover { stack.hoverChanged($0) }
        .frame(height: stack.viewportHeight, alignment: .bottom)
    }

    private var header: some View {
        HStack {
            Label("\(stack.items.count) screenshots", systemImage: "square.on.square")
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
            Button {
                stack.toggleExpanded()
            } label: {
                Label(stack.expanded ? "Collapse" : "Expand", systemImage: stack.expanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(width: QuickAccessStackStyle.cardSize.width, height: QuickAccessStackStyle.headerHeight)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
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

    var body: some View {
        if let content = entry.previewView {
            content.keyboardActionsEnabled(selected)
                .frame(width: QuickAccessStackStyle.cardSize.width, height: QuickAccessStackStyle.cardSize.height)
                .modifier(QuickAccessCardShadow())
                .scaleEffect(expanded ? 1 : max(QuickAccessStackStyle.minimumLayerScale, 1 - CGFloat(index) * QuickAccessStackStyle.layerScaleStep), anchor: .bottom)
                .rotationEffect(.degrees(expanded || index == 0 ? 0 : QuickAccessStackStyle.layerAngles[min(index, QuickAccessStackStyle.visibleDepth - 1)]))
                .offset(y: -rowOffset)
                .opacity(expanded || index < QuickAccessStackStyle.visibleDepth ? 1 : 0)
                .allowsHitTesting(expanded || index == 0)
                .accessibilityHidden(!expanded && index != 0)
                .zIndex(Double(count - index))
                .visualEffect { view, geometry in
                    view.scaleEffect(QuickAccessStackStyle.scrollScale(y: geometry.frame(in: .scrollView).minY - rowOffset, expanded: expanded), anchor: .bottom)
                }
                .transition(.asymmetric(insertion: .offset(y: QuickAccessStackStyle.insertionOffset).combined(with: .opacity), removal: .opacity))
        }
    }

    nonisolated private var rowOffset: CGFloat {
        expanded ? CGFloat(index) * (QuickAccessStackStyle.cardSize.height + QuickAccessStackStyle.rowSpacing)
            : CGFloat(min(index, QuickAccessStackStyle.visibleDepth - 1)) * QuickAccessStackStyle.layerStep
    }
}
