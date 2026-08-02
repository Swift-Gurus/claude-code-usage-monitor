import SwiftUI

/// Renders the flattened divider/header/agent list, measuring each row's height for
/// viewport sizing.
struct PopoverAgentListContent<AccountHeader: View>: View {
    let items: [PopoverAgentListItem]
    let colors: PopoverColors
    @ViewBuilder let accountHeader: (PopoverAccountGroup) -> AccountHeader
    let onSelectAgent: (AgentInfo) -> Void

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            measuredRow(index: index, item: item)
        }
    }

    private func measuredRow(index: Int, item: PopoverAgentListItem) -> some View {
        rowContent(item)
            .background(heightReader(index: index))
    }

    private func heightReader(index: Int) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: AgentRowHeightsKey.self, value: [index: geo.size.height])
        }
    }

    @ViewBuilder
    private func rowContent(_ item: PopoverAgentListItem) -> some View {
        switch item {
        case .divider:
            Divider().padding(.vertical, 4)
        case .header(let group):
            accountHeader(group)
        case .agent(let agent):
            PopoverAgentRowView(agent: agent, colors: colors, onTap: { onSelectAgent(agent) })
                .padding(.leading, 8)
        }
    }
}

#Preview {
    PopoverAgentListContent(
        items: [.divider("d1")],
        colors: PopoverColors(colorScheme: .light),
        accountHeader: { (_: PopoverAccountGroup) in EmptyView() },
        onSelectAgent: { _ in }
    )
}
