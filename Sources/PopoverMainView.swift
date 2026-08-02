import SwiftUI

/// Composes the popover's landing screen: title/settings header, period table + agent
/// list, and the footer (open-project, statusline status, quit).
struct PopoverMainView<VM: PopoverAgentListViewState & PopoverAgentListViewActions>: View {
    let viewModel: VM
    let settings: AppSettings
    @Binding var filterAccountID: UUID?
    let statsResolver: PeriodStatsResolving
    let rateLimitEvents: [UUID: RateLimitEvent]
    let statsCaches: [UUID: StatsCache]
    let colors: PopoverColors
    let onOpenSettings: () -> Void
    let onSelectPeriod: (String) -> Void
    let onSelectAgent: (AgentInfo) -> Void
    let onOpenProject: () -> Void
    let onInstallStatusline: (Account) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            agentSection
            Divider()
            footerSection
        }
    }

    private var headerSection: some View {
        PopoverMainHeaderSection(accounts: settings.accounts, filterAccountID: $filterAccountID, onOpenSettings: onOpenSettings)
    }

    private var agentSection: some View {
        PopoverMainAgentSection(
            viewModel: viewModel,
            dayStats: statsResolver.stats(for: "Today"), weekStats: statsResolver.stats(for: "Week"), monthStats: statsResolver.stats(for: "Month"),
            rateLimitEvents: rateLimitEvents, statsCaches: statsCaches, colors: colors,
            onSelectPeriod: onSelectPeriod, onSelectAgent: onSelectAgent
        )
    }

    private var footerSection: some View {
        PopoverMainFooterSection(accounts: settings.accounts, onOpenProject: onOpenProject, onInstallStatusline: onInstallStatusline)
    }
}
