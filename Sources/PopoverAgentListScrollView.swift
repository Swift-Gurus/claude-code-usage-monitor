import SwiftUI

/// Scrollable, height-bounded agent list with per-row height measurement.
struct PopoverAgentListScrollView<AccountHeader: View>: View {
    let items: [PopoverAgentListItem]
    let colors: PopoverColors
    let rowSpacing: CGFloat
    let viewportHeight: CGFloat?
    @ViewBuilder let accountHeader: (PopoverAccountGroup) -> AccountHeader
    let onSelectAgent: (AgentInfo) -> Void
    let onRowHeightsChange: ([Int: CGFloat]) -> Void

    var body: some View {
        scrollContent
    }

    private var scrollContent: some View {
        ScrollView {
            PopoverAgentListContainerView(items: items, colors: colors, rowSpacing: rowSpacing, accountHeader: accountHeader, onSelectAgent: onSelectAgent)
        }
        .scrollIndicators(.never)
        .frame(height: viewportHeight)
        .onPreferenceChange(AgentRowHeightsKey.self, perform: onRowHeightsChange)
    }
}

#Preview {
    PopoverAgentListScrollView(
        items: [.divider("d1")],
        colors: PopoverColors(colorScheme: .light),
        rowSpacing: 6,
        viewportHeight: nil,
        accountHeader: { (_: PopoverAccountGroup) in EmptyView() },
        onSelectAgent: { _ in },
        onRowHeightsChange: { _ in }
    )
}
