import SwiftUI

/// Folder/branch/source tags, and lines-added/removed for one agent row.
struct PopoverAgentDetailRow: View {
    let agent: AgentInfo
    let addedColor: Color
    let removedColor: Color

    var body: some View {
        HStack {
            PopoverAgentTagsSection(agent: agent)
            Spacer()
            LinesDeltaView(added: agent.linesAdded, removed: agent.linesRemoved, addedColor: addedColor, removedColor: removedColor)
        }
    }
}

#Preview {
    PopoverAgentDetailRow(
        agent: AgentInfo(
            pid: 1, model: "Sonnet", agentName: "Preview", contextPercent: 40, contextWindow: 200_000,
            cost: 1.25, linesAdded: 10, linesRemoved: 2, workingDir: "/tmp", sessionID: "s",
            durationMs: 0, apiDurationMs: 0, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
        ),
        addedColor: .green, removedColor: .red
    )
}
