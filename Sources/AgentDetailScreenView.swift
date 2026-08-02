import SwiftUI

/// Popover navigation branch: an agent's detail screen.
struct AgentDetailScreenView<VM: SubagentDetailState & SubagentDetailActions>: View {
    let agent: AgentInfo
    let agentTracker: AgentTracker
    let settings: AppSettings
    let sessionManager: SessionManager
    let vm: VM
    let onDismiss: () -> Void

    var body: some View {
        SubagentDetailView(
            agent: agent, agentTracker: agentTracker, settings: settings, sessionManager: sessionManager,
            vm: vm, onDismiss: onDismiss
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    return AgentDetailScreenView(
        agent: agent, agentTracker: tracker, settings: settings, sessionManager: SessionManager(),
        vm: SubagentDetailViewModel(agent: agent, settings: settings, codexSessions: tracker.codexSessions),
        onDismiss: {}
    )
}
