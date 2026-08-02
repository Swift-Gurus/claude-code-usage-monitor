import SwiftUI

/// The header, context/duration progress row, and detail line for one agent row.
struct PopoverAgentRowContent: View {
    let agent: AgentInfo
    let colors: PopoverColors

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PopoverAgentHeaderRow(agent: agent, idleColor: colors.idle)
            AgentProgressSection(agent: agent)
            PopoverAgentDetailRow(agent: agent, addedColor: colors.added, removedColor: colors.removed)
        }
    }
}

#Preview {
    PopoverAgentRowContent(
        agent: AgentInfo(
            pid: 1, model: "Sonnet", agentName: "Preview", contextPercent: 40, contextWindow: 200_000,
            cost: 1.25, linesAdded: 10, linesRemoved: 2, workingDir: "/tmp", sessionID: "s",
            durationMs: 0, apiDurationMs: 0, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
        ),
        colors: PopoverColors(colorScheme: .light)
    )
}
