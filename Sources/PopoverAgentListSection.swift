import SwiftUI

/// Scrollable agent list, or a loading/empty placeholder when there's nothing to show yet.
struct PopoverAgentListSection<AccountHeader: View>: View {
    let items: [PopoverAgentListItem]
    let hasAgents: Bool
    let isLoading: Bool
    let colors: PopoverColors
    let rowSpacing: CGFloat
    let viewportHeight: CGFloat?
    @ViewBuilder let accountHeader: (PopoverAccountGroup) -> AccountHeader
    let onSelectAgent: (AgentInfo) -> Void
    let onRowHeightsChange: ([Int: CGFloat]) -> Void

    var body: some View {
        if hasAgents {
            PopoverAgentListScrollView(
                items: items, colors: colors, rowSpacing: rowSpacing, viewportHeight: viewportHeight,
                accountHeader: accountHeader, onSelectAgent: onSelectAgent, onRowHeightsChange: onRowHeightsChange
            )
        } else if isLoading {
            LoadingStateView(message: "Loading active agents...")
        } else {
            EmptyStateView(message: "No active agents")
        }
    }
}
