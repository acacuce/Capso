import AppKit

/// Shared by capture and recording. Membership and window ownership are the
/// same for both media types; callbacks continue to own their export workflow.
@MainActor
final class QuickAccessPreviewStore {
    private(set) var items: [QuickAccessItem] = []
    private(set) var stacks: [CGDirectDisplayID: QuickAccessStackModel] = [:]

    func insert(_ item: QuickAccessItem) {
        items.append(item)
        updateStacks()
        item.activateAutoDismiss()
    }

    func remove(_ item: QuickAccessItem) {
        guard let index = items.firstIndex(where: { $0 === item }) else { return }
        items.remove(at: index)
        item.close()
        updateStacks()
    }

    private func updateStacks() {
        let groups = Dictionary(grouping: items) { $0.targetScreen.displayID }
        for id in Array(stacks.keys) where groups[id] == nil {
            stacks.removeValue(forKey: id)?.stop()
        }
        for (id, entries) in groups {
            let stack = stacks[id] ?? QuickAccessStackModel()
            stacks[id] = stack
            stack.update(items: entries)
        }
    }
}
