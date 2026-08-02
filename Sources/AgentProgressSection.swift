import SwiftUI

/// Context-window progress bar plus elapsed-duration label for one agent row.
struct AgentProgressSection: View {
    let agent: AgentInfo

    var body: some View {
        HStack(spacing: 8) {
            ContextProgressBar(
                contextPercent: agent.contextPercent,
                label: agent.contextWindowText.isEmpty ? "" : "· \(agent.contextWindowText)",
                barWidth: 60
            )
            durationLabel
        }
    }

    private var durationLabelBase: some View {
        Label(agent.durationText, systemImage: "clock")
    }

    private var durationLabel: some View {
        durationLabelBase.font(.caption2).foregroundStyle(.secondary)
    }
}

#Preview {
    AgentProgressSection(
        agent: AgentInfo(
            pid: 1, model: "Sonnet", agentName: "Preview", contextPercent: 40, contextWindow: 200_000,
            cost: 1.25, linesAdded: 10, linesRemoved: 2, workingDir: "/tmp", sessionID: "s",
            durationMs: 0, apiDurationMs: 0, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
        )
    )
}
