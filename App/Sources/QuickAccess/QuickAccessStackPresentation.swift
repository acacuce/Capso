import SwiftUI

@MainActor @Observable
final class QuickAccessStackPresentation {
    var angle: Double = 0
    var scale: CGFloat = 1
    var count = 1
    var expanded = false
    var isFront = false
    var pageStart = 0
    var pageSize = 1
    var onExpand: (() -> Void)?
    var onPage: ((Int) -> Void)?
}

struct QuickAccessStackCard: View {
    let content: QuickAccessView
    let presentation: QuickAccessStackPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .frame(width: QuickAccessStackStyle.cardSize.width, height: QuickAccessStackStyle.cardSize.height)
            .overlay(alignment: .topLeading) {
                if presentation.isFront && presentation.count > 1 {
                    stackControls.padding(12)
                }
            }
            .scaleEffect(presentation.scale)
            .rotationEffect(.degrees(presentation.angle))
            .animation(reduceMotion ? nil : .spring(response: QuickAccessStackStyle.transitionDuration, dampingFraction: QuickAccessStackStyle.transitionDamping), value: presentation.angle)
            .animation(reduceMotion ? nil : .spring(response: QuickAccessStackStyle.transitionDuration, dampingFraction: QuickAccessStackStyle.transitionDamping), value: presentation.scale)
            .frame(width: QuickAccessStackStyle.panelSize.width, height: QuickAccessStackStyle.panelSize.height)
    }

    private var stackControls: some View {
        HStack(spacing: 6) {
            if presentation.expanded && presentation.count > presentation.pageSize {
                Button { presentation.onPage?(-1) } label: { Image(systemName: "chevron.up") }
                    .disabled(presentation.pageStart == 0)
                    .accessibilityLabel("Newer screenshots")
                Text("\(presentation.pageStart + 1)–\(min(presentation.count, presentation.pageStart + presentation.pageSize)) / \(presentation.count)")
                    .monospacedDigit()
                Button { presentation.onPage?(1) } label: { Image(systemName: "chevron.down") }
                    .disabled(presentation.pageStart + presentation.pageSize >= presentation.count)
                    .accessibilityLabel("Older screenshots")
            } else {
                Button { presentation.onExpand?() } label: {
                    Label("\(presentation.count)", systemImage: "square.on.square")
                }
                .accessibilityLabel("Expand \(presentation.count) screenshots")
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}
