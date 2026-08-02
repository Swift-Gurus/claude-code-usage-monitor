import SwiftUI

/// Wires a `PopoverAgentListViewState & PopoverAgentListViewActions` view model into
/// `PopoverAgentListSection`, resolving each account group's header data as it renders.
struct PopoverMainAgentListContainer<VM: PopoverAgentListViewState & PopoverAgentListViewActions>: View {
    let viewModel: VM
    let rateLimitEvents: [UUID: RateLimitEvent]
    let statsCaches: [UUID: StatsCache]
    let colors: PopoverColors
    let onSelectAgent: (AgentInfo) -> Void

    var body: some View {
        PopoverAgentListSection(
            items: viewModel.items, hasAgents: viewModel.hasAgents, isLoading: false, colors: colors,
            rowSpacing: 6, viewportHeight: viewModel.agentViewportHeight,
            accountHeader: { group in accountHeaderView(for: group) },
            onSelectAgent: onSelectAgent,
            onRowHeightsChange: { viewModel.updateRowHeights($0) }
        )
    }

    private func accountHeaderView(for group: PopoverAccountGroup) -> some View {
        let headerData = viewModel.headerData(for: group, rateLimitEvents: rateLimitEvents, statsCaches: statsCaches)
        return PopoverAccountHeader(
            group: group, displayName: headerData.displayName, showPlanCard: headerData.showPlanCard,
            freshRateLimitEvent: headerData.rateLimitEvent, liveRateLimits: headerData.liveRateLimits,
            periodStats: headerData.periodStats, statsCache: headerData.statsCache
        )
    }
}

#Preview {
    PopoverMainAgentListContainer(
        viewModel: PopoverMainViewModel(settings: AppSettings(), agentTracker: AgentTracker(), data: UsageData()),
        rateLimitEvents: [:], statsCaches: [:], colors: PopoverColors(colorScheme: .light), onSelectAgent: { _ in }
    )
}
