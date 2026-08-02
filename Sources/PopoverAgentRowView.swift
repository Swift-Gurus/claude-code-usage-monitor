import SwiftUI

/// One agent's row in the popover's agent list: header, context/duration, and detail line.
struct PopoverAgentRowView: View {
    let agent: AgentInfo
    let colors: PopoverColors
    let onTap: () -> Void

    var body: some View {
        PopoverAgentRowContent(agent: agent, colors: colors)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .opacity(agent.isIdle ? colors.idleOpacity : 1.0)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

#Preview {
    PopoverAgentRowView(
        agent: AgentInfo(
            pid: 1, model: "Sonnet", agentName: "Preview", contextPercent: 40, contextWindow: 200_000,
            cost: 1.25, linesAdded: 10, linesRemoved: 2, workingDir: "/tmp", sessionID: "s",
            durationMs: 0, apiDurationMs: 0, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
        ),
        colors: PopoverColors(colorScheme: .light),
        onTap: {}
    )
}
