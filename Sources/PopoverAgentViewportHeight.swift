import Foundation

/// Bounded scroll viewport height for the popover's agent list: fits `maxVisibleAgents`
/// agent cards (headers/dividers don't count toward the limit).
struct PopoverAgentViewportHeight {
    let items: [PopoverAgentListItem]
    let maxVisibleAgents: Int
    let rowHeights: [Int: CGFloat]
    let rowSpacing: CGFloat
    let useNaturalHeight: Bool

    var value: CGFloat? {
        if useNaturalHeight { return nil }
        guard !items.isEmpty else { return nil }
        let n = rowCountForVisibleAgents
        guard rowHeights.count >= n else { return nil }
        let height = (0..<n).compactMap { rowHeights[$0] }.reduce(0, +)
        return height + rowSpacing * CGFloat(max(0, n - 1))
    }

    private var rowCountForVisibleAgents: Int {
        var agentsSeen = 0
        var count = 0
        for item in items {
            count += 1
            if case .agent = item { agentsSeen += 1 }
            if agentsSeen >= maxVisibleAgents { break }
        }
        return count
    }
}
