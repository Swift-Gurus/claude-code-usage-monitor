import SwiftUI

/// Status dot + name + model, the leading half of an agent row's header.
struct PopoverAgentLeadingSection: View {
    let agent: AgentInfo
    let idleColor: Color

    var body: some View {
        HStack {
            statusDot
            nameText
            modelTextIfNeeded
        }
    }

    private var statusDot: some View {
        Image(systemName: agent.isIdle ? "moon.zzz.fill" : "circle.fill")
            .font(.system(size: 8))
            .foregroundStyle(agent.isIdle ? idleColor : .green)
    }

    private var nameText: some View {
        Text(agent.displayName).font(.caption).fontWeight(.medium).lineLimit(1)
    }

    @ViewBuilder
    private var modelTextIfNeeded: some View {
        if !agent.agentName.isEmpty {
            modelText
        }
    }

    private var modelText: some View {
        Text(agent.model).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
    }
}

#Preview {
    PopoverAgentLeadingSection(
        agent: AgentInfo(
            pid: 1, model: "Sonnet", agentName: "Preview", contextPercent: 40, contextWindow: 200_000,
            cost: 1.25, linesAdded: 10, linesRemoved: 2, workingDir: "/tmp", sessionID: "s",
            durationMs: 0, apiDurationMs: 0, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
        ),
        idleColor: .gray
    )
}
