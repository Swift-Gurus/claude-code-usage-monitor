import SwiftUI

/// Spacing-configured VStack wrapping the flattened agent list content.
struct PopoverAgentListContainerView<AccountHeader: View>: View {
    let items: [PopoverAgentListItem]
    let colors: PopoverColors
    let rowSpacing: CGFloat
    @ViewBuilder let accountHeader: (PopoverAccountGroup) -> AccountHeader
    let onSelectAgent: (AgentInfo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            PopoverAgentListContent(items: items, colors: colors, accountHeader: accountHeader, onSelectAgent: onSelectAgent)
        }
    }
}

#Preview {
    PopoverAgentListContainerView(
        items: [.divider("d1")],
        colors: PopoverColors(colorScheme: .light),
        rowSpacing: 6,
        accountHeader: { (_: PopoverAccountGroup) in EmptyView() },
        onSelectAgent: { _ in }
    )
}
