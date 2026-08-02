import SwiftUI

/// Status dot, name/model, and trailing idle-time-or-tokens + cost for one agent row.
struct PopoverAgentHeaderRow: View {
    let agent: AgentInfo
    let idleColor: Color

    var body: some View {
        HStack {
            PopoverAgentLeadingSection(agent: agent, idleColor: idleColor)
            Spacer()
            PopoverAgentTrailingSection(agent: agent, idleColor: idleColor)
        }
    }
}

#Preview {
    PopoverAgentHeaderRow(
        agent: AgentInfo(
            pid: 1, model: "Sonnet", agentName: "Preview", contextPercent: 40, contextWindow: 200_000,
            cost: 1.25, linesAdded: 10, linesRemoved: 2, workingDir: "/tmp", sessionID: "s",
            durationMs: 0, apiDurationMs: 0, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
        ),
        idleColor: .gray
    )
}
