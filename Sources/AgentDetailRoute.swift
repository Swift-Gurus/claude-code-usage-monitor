import SwiftUI

/// Popover router branch for an agent's detail screen.
struct AgentDetailRoute: View {
    let agent: AgentInfo
    let mainViewModel: any PopoverAgentListViewState & PopoverAgentListViewActions
    let agentTracker: AgentTracker
    let settings: AppSettings
    let sessionManager: SessionManager
    let navigation: PopoverNavigationState

    var body: some View {
        let liveAgent = mainViewModel.liveAgent(for: agent)
        AgentDetailScreenView(
            agent: liveAgent, agentTracker: agentTracker, settings: settings, sessionManager: sessionManager,
            vm: SubagentDetailViewModel(agent: liveAgent, settings: settings, codexSessions: agentTracker.codexSessions),
            onDismiss: navigation.dismissAgent
        )
    }
}

#Preview {
    let tracker = AgentTracker()
    let settings = AppSettings()
    let agent = AgentInfo(
        pid: 1, model: "claude-opus", agentName: "", contextPercent: 40, contextWindow: 200_000,
        cost: 1.23, linesAdded: 10, linesRemoved: 2, workingDir: "/tmp", sessionID: "preview",
        durationMs: 1000, apiDurationMs: 500, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
    )
    return AgentDetailRoute(
        agent: agent, mainViewModel: PopoverMainViewModel(settings: settings, agentTracker: tracker, data: UsageData()),
        agentTracker: tracker, settings: settings, sessionManager: SessionManager(), navigation: PopoverNavigationState()
    )
}
