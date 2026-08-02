import SwiftUI

/// Popover router branch for the landing screen.
struct MainRoute<VM: PopoverAgentListViewState & PopoverAgentListViewActions>: View {
    let mainViewModel: VM
    let statsResolver: PeriodStatsResolving
    let settings: AppSettings
    let navigation: PopoverNavigationState
    let rateLimitStore: RateLimitEventStore
    let statsCacheStore: StatsCacheStore
    let colors: PopoverColors
    let projectOpener: ProjectOpening
    let statuslineInstaller: StatuslineInstalling

    var body: some View {
        MainScreenView(
            viewModel: mainViewModel, statsResolver: statsResolver,
            settings: settings, filterAccountID: Binding(get: { navigation.filterAccountID }, set: { navigation.filterAccountID = $0 }),
            rateLimitStore: rateLimitStore, statsCacheStore: statsCacheStore, colors: colors,
            onOpenSettings: navigation.openSettings,
            onSelectPeriod: { navigation.select(period: $0) },
            onSelectAgent: { navigation.select(agent: $0) },
            onOpenProject: { if let agent = projectOpener.openProject() { navigation.select(agent: agent) } },
            onInstallStatusline: { _ = statuslineInstaller.install(claudeDir: $0.claudeDir) }
        )
    }
}

#Preview {
    MainRoute(
        mainViewModel: PopoverMainViewModel(settings: AppSettings(), agentTracker: AgentTracker(), data: UsageData()),
        statsResolver: PopoverPeriodStatsResolver(data: UsageData(), filterAccountID: nil),
        settings: AppSettings(), navigation: PopoverNavigationState(),
        rateLimitStore: RateLimitEventStore(), statsCacheStore: StatsCacheStore(),
        colors: PopoverColors(colorScheme: .light),
        projectOpener: PopoverProjectOpener(sessionManager: SessionManager()),
        statuslineInstaller: DefaultStatuslineInstaller()
    )
}
