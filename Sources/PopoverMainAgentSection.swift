import SwiftUI

/// Period table plus the scrollable working/idle agent list for the popover main screen.
struct PopoverMainAgentSection<VM: PopoverAgentListViewState & PopoverAgentListViewActions>: View {
    let viewModel: VM
    let dayStats: PeriodStats
    let weekStats: PeriodStats
    let monthStats: PeriodStats
    let rateLimitEvents: [UUID: RateLimitEvent]
    let statsCaches: [UUID: StatsCache]
    let colors: PopoverColors
    let onSelectPeriod: (String) -> Void
    let onSelectAgent: (AgentInfo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PopoverPeriodTable(dayStats: dayStats, weekStats: weekStats, monthStats: monthStats, onSelect: onSelectPeriod)
            Divider()
            PopoverMainAgentListContainer(
                viewModel: viewModel, rateLimitEvents: rateLimitEvents, statsCaches: statsCaches,
                colors: colors, onSelectAgent: onSelectAgent
            )
        }
    }
}

#Preview {
    PopoverMainAgentSection(
        viewModel: PopoverMainViewModel(settings: AppSettings(), agentTracker: AgentTracker(), data: UsageData()),
        dayStats: PeriodStats(), weekStats: PeriodStats(), monthStats: PeriodStats(),
        rateLimitEvents: [:], statsCaches: [:], colors: PopoverColors(colorScheme: .light),
        onSelectPeriod: { _ in }, onSelectAgent: { _ in }
    )
}
