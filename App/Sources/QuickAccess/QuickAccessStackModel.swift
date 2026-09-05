import AppKit
import SwiftUI

/// One native window and one SwiftUI hierarchy per display. Entries retain their
/// action callbacks; membership changes don't reorder or animate native windows.
@MainActor @Observable
final class QuickAccessStackModel {
    private(set) var items: [QuickAccessItem] = [] // newest first
    var activeItemID: UUID?
    private(set) var expanded = false
    private(set) var expandsUp = true
    private(set) var viewportHeight: CGFloat = QuickAccessStackStyle.collapsedHeight
    private(set) var panel: QuickAccessStackPanel?
    private var collapseTask: Task<Void, Never>?
    private var resizeTask: Task<Void, Never>?
    private var dragging = false
    private var scrolling = false
    private var hovered = false
    private var hoveredItems: Set<UUID> = []
    private var pinnedOpen = false
    private var suppressHoverUntilExit = false
    #if DEBUG
    var addDemoItem: (() -> Void)?
    func loadPreviewItems(_ items: [QuickAccessItem], expanded: Bool = false) {
        self.items = Array(items.reversed())
        activeItemID = self.items.first?.id
        self.expanded = expanded
        viewportHeight = expanded ? expandedHeight : QuickAccessStackStyle.collapsedHeight
    }
    #endif

    func update(items: [QuickAccessItem]) {
        let incoming = Array(items.reversed())
        if incoming.isEmpty {
            self.items = []
            stop()
            return
        }
        if panel == nil {
            panel = QuickAccessStackPanel(controller: self, screen: incoming[0].targetScreen,
                                          initialOrigin: incoming[0].initialStackOrigin)
        }
        hoveredItems.formIntersection(incoming.map(\.id))
        for item in incoming { item.stackController = self }
        withAnimation(animation) { self.items = incoming }
        activeItemID = incoming.first?.id
        if expanded {
            viewportHeight = expandedHeight
            panel?.resizeViewport(to: viewportHeight)
        }
        panel?.orderFrontRegardless()
        panel?.makeKey()
        for item in incoming { item.setStackInteractionActive(hovered || expanded) }
    }

    var animation: Animation? {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .spring(response: QuickAccessStackStyle.transitionDuration, dampingFraction: QuickAccessStackStyle.transitionDamping)
    }

    func stop() {
        collapseTask?.cancel()
        resizeTask?.cancel()
        panel?.cancelMotion()
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        expanded = false
        viewportHeight = QuickAccessStackStyle.collapsedHeight
        pinnedOpen = false
        hovered = false
        hoveredItems.removeAll()
        dragging = false
        scrolling = false
    }

    var hasOverflow: Bool {
        let style = QuickAccessStackStyle.self
        let contentHeight = style.headerHeight + style.listTopPadding + style.layerStep * 2
            + style.expandedContentHeight(count: items.count) + style.shadowGutter
        return contentHeight > viewportHeight
    }

    private var expandedHeight: CGFloat {
        QuickAccessStackStyle.expandedViewportHeight(
            count: items.count,
            visibleHeight: (panel?.screen ?? items.first?.targetScreen)?.visibleFrame.height ?? 800
        )
    }

    func expand() {
        guard items.count > 1, !expanded else { return }
        collapseTask?.cancel()
        resizeTask?.cancel()
        if let panel {
            expandsUp = panel.frame.midY < ((panel.screen ?? items.first?.targetScreen)?.visibleFrame.midY ?? 400)
        }
        viewportHeight = expandedHeight
        panel?.resizeViewport(to: viewportHeight)
        withAnimation(animation) { expanded = true }
        items.forEach { $0.setStackInteractionActive(true) }
    }

    func toggleExpanded() {
        pinnedOpen = !expanded
        if expanded {
            suppressHoverUntilExit = true
            collapse()
        } else { expand() }
    }

    func collapse() {
        collapseTask?.cancel()
        guard expanded else { return }
        withAnimation(animation) { expanded = false }
        resizeTask?.cancel()
        resizeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(QuickAccessStackStyle.transitionDuration))
            guard !Task.isCancelled, let self, !self.expanded else { return }
            self.viewportHeight = QuickAccessStackStyle.collapsedHeight
            self.panel?.resizeViewport(to: self.viewportHeight)
        }
        items.forEach { $0.setStackInteractionActive(hovered) }
    }

    /// SwiftUI reports tracking, interaction and momentum without polling.
    /// Keep the list and its items alive until scrolling returns to idle.
    func scrollInteractionChanged(active: Bool) {
        guard scrolling != active else { return }
        scrolling = active
        hoverChanged(hovered)
    }

    func cardHoverChanged(id: UUID, inside: Bool) {
        if inside { hoveredItems.insert(id) } else { hoveredItems.remove(id) }
        hoverChanged(!hoveredItems.isEmpty)
    }

    func hoverChanged(_ inside: Bool) {
        hovered = inside
        if !inside { suppressHoverUntilExit = false }
        collapseTask?.cancel()
        items.forEach { $0.setStackInteractionActive(inside || dragging || scrolling || (expanded && pinnedOpen)) }
        guard !dragging, !scrolling else { return }
        if inside && !expanded && !suppressHoverUntilExit {
            // A short dwell keeps passing the pointer over the pile from opening it.
            collapseTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(QuickAccessStackStyle.hoverDwell))
                guard !Task.isCancelled else { return }
                self?.expand()
            }
        } else if !inside && !pinnedOpen {
            collapseTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(QuickAccessStackStyle.collapseDelay))
                guard !Task.isCancelled else { return }
                self?.collapse()
            }
        }
    }

    func beginPanelDrag() {
        dragging = true
        collapseTask?.cancel()
        resizeTask?.cancel()
        panel?.cancelMotion()
        items.forEach { $0.setStackInteractionActive(true) }
    }

    func endExternalDrag() {
        dragging = false
        hoverChanged(hovered)
    }

    func endPanelDrag(velocity: CGPoint) {
        dragging = false
        if !expanded {
            viewportHeight = QuickAccessStackStyle.collapsedHeight
            panel?.resizeViewport(to: viewportHeight)
        }
        panel?.snap(velocity: velocity)
        hoverChanged(false)
    }

}
