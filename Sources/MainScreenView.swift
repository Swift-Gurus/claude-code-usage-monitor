import SwiftUI

/// Popover navigation branch: the landing screen (period table + agent list + footer).
struct MainScreenView<VM: PopoverAgentListViewState & PopoverAgentListViewActions>: View {
    let viewModel: VM
    let statsResolver: PeriodStatsResolving
    let settings: AppSettings
    @Binding var filterAccountID: UUID?
    let rateLimitStore: RateLimitEventStore
    let statsCacheStore: StatsCacheStore
    let colors: PopoverColors
    let onOpenSettings: () -> Void
    let onSelectPeriod: (String) -> Void
    let onSelectAgent: (AgentInfo) -> Void
    let onOpenProject: () -> Void
    let onInstallStatusline: (Account) -> Void

    var body: some View {
        PopoverScreenScroll(displayMode: settings.displayMode, content: mainContent)
    }

    private func mainContent() -> some View {
        PopoverMainView(
            viewModel: viewModel, settings: settings, filterAccountID: $filterAccountID,
            statsResolver: statsResolver, rateLimitEvents: rateLimitStore.events, statsCaches: statsCacheStore.caches,
            colors: colors, onOpenSettings: onOpenSettings, onSelectPeriod: onSelectPeriod, onSelectAgent: onSelectAgent,
            onOpenProject: onOpenProject, onInstallStatusline: onInstallStatusline
        )
        .task {
            rateLimitStore.reload(accounts: settings.accounts)
            statsCacheStore.reload(accounts: settings.accounts)
        }
    }
}

#Preview {
    MainScreenView(
        viewModel: PopoverMainViewModel(settings: AppSettings(), agentTracker: AgentTracker(), data: UsageData()),
        statsResolver: PopoverPeriodStatsResolver(data: UsageData(), filterAccountID: nil),
        settings: AppSettings(), filterAccountID: .constant(nil),
        rateLimitStore: RateLimitEventStore(), statsCacheStore: StatsCacheStore(),
        colors: PopoverColors(colorScheme: .light),
        onOpenSettings: {}, onSelectPeriod: { _ in }, onSelectAgent: { _ in },
        onOpenProject: {}, onInstallStatusline: { _ in }
    )
}
