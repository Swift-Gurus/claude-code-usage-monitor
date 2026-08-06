import SwiftUI

struct PopoverView<VM: PopoverAgentListViewState & PopoverAgentListViewActions>: View {
    var data: UsageData
    var agentTracker: AgentTracker
    var settings: AppSettings
    var sessionManager: SessionManager

    @Environment(\.colorScheme) private var colorScheme
    @State private var mainViewModel: VM
    @State private var navigation = PopoverNavigationState()
    @State private var rateLimitStore = RateLimitEventStore()
    @State private var statsCacheStore = StatsCacheStore()
    @State private var statsPageDataSource: StatsPageDataSource
    private let projectOpener: ProjectOpening
    private let statuslineInstaller: StatuslineInstalling

    init(
        data: UsageData, agentTracker: AgentTracker, settings: AppSettings, sessionManager: SessionManager,
        mainViewModel: VM,
        projectOpener: ProjectOpening? = nil,
        statuslineInstaller: StatuslineInstalling = DefaultStatuslineInstaller()
    ) {
        self.data = data
        self.agentTracker = agentTracker
        self.settings = settings
        self.sessionManager = sessionManager
        self.projectOpener = projectOpener ?? PopoverProjectOpener(sessionManager: sessionManager)
        self.statuslineInstaller = statuslineInstaller
        _mainViewModel = State(initialValue: mainViewModel)
        _statsPageDataSource = State(initialValue: StatsPageDataSource(accounts: settings.accounts))
    }

    var body: some View {
        router
            .preferredColorScheme(settings.appearanceMode.colorScheme)
            .task { statsPageDataSource.reload() }
    }

    @ViewBuilder
    private var router: some View {
        if navigation.showSettings {
            SettingsRoute(settings: settings, navigation: navigation)
        } else if let agent = navigation.selectedAgent {
            AgentDetailRoute(
                agent: agent, mainViewModel: mainViewModel, agentTracker: agentTracker,
                settings: settings, sessionManager: sessionManager, navigation: navigation
            )
        } else if let period = navigation.statsPagePeriod {
            StatsPageRoute(
                data: data, settings: settings, dataSource: statsPageDataSource,
                period: period, navigation: navigation
            )
        } else if let label = navigation.selectedPeriod {
            PeriodDetailRoute(
                label: label, statsResolver: PopoverPeriodStatsResolver(data: data, filterAccountID: navigation.filterAccountID),
                settings: settings, navigation: navigation
            )
        } else {
            MainRoute(
                mainViewModel: mainViewModel,
                statsResolver: PopoverPeriodStatsResolver(data: data, filterAccountID: navigation.filterAccountID),
                settings: settings, navigation: navigation,
                rateLimitStore: rateLimitStore, statsCacheStore: statsCacheStore,
                colors: PopoverColors(colorScheme: colorScheme),
                projectOpener: projectOpener, statuslineInstaller: statuslineInstaller
            )
        }
    }
}

#Preview {
    PopoverView(
        data: UsageData(), agentTracker: AgentTracker(), settings: AppSettings(), sessionManager: SessionManager(),
        mainViewModel: PopoverMainViewModel(settings: AppSettings(), agentTracker: AgentTracker(), data: UsageData())
    )
}
