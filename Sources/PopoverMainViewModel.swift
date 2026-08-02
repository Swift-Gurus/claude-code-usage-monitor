import Foundation

/**
 solid-name: PopoverMainViewModel
 solid-category: viewmodel
 solid-description: Provides agent data and viewport sizing for popover display.
 */
@Observable
final class PopoverMainViewModel {
    private let settings: AppSettings
    private let agentTracker: AgentTracker
    private let data: UsageData
    private(set) var agentRowHeights: [Int: CGFloat] = [:]

    init(settings: AppSettings, agentTracker: AgentTracker, data: UsageData) {
        self.settings = settings
        self.agentTracker = agentTracker
        self.data = data
    }

    var workingAgents: [AgentInfo] {
        PopoverAgentSorting(sortOrder: settings.agentSortOrder).sorted(agentTracker.activeAgents.filter { !$0.isIdle })
    }

    var idleAgents: [AgentInfo] {
        PopoverAgentSorting(sortOrder: settings.agentSortOrder).sorted(agentTracker.activeAgents.filter(\.isIdle))
    }

    var hasAgents: Bool {
        !workingAgents.isEmpty || !idleAgents.isEmpty
    }

    var groups: [PopoverAccountGroup] {
        PopoverAgentGrouping(accounts: settings.accounts, workingAgents: workingAgents, idleAgents: idleAgents).groups
    }

    var items: [PopoverAgentListItem] {
        PopoverAgentListFlattener(groups: groups).items
    }

    var agentViewportHeight: CGFloat? {
        PopoverAgentViewportHeight(
            items: items, maxVisibleAgents: settings.maxVisibleAgents, rowHeights: agentRowHeights,
            rowSpacing: 6, useNaturalHeight: settings.displayMode == .window
        ).value
    }

    func updateRowHeights(_ heights: [Int: CGFloat]) {
        agentRowHeights = heights
    }

    /// Live data for a previously-selected agent, falling back to the stale snapshot
    /// if the tracker no longer reports that PID.
    func liveAgent(for agent: AgentInfo) -> AgentInfo {
        agentTracker.activeAgents.first(where: { $0.pid == agent.pid }) ?? agent
    }

    func headerData(for group: PopoverAccountGroup, rateLimitEvents: [UUID: RateLimitEvent], statsCaches: [UUID: StatsCache]) -> PopoverAccountHeaderData {
        PopoverAccountHeaderData(
            group: group, accounts: settings.accounts, activeAgents: agentTracker.activeAgents,
            byAccount: data.byAccount, rateLimitEvents: rateLimitEvents, statsCaches: statsCaches
        )
    }
}
