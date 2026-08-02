import SwiftUI

/// Idle time (if idle) + cost-or-tokens, the trailing half of an agent row's header.
struct PopoverAgentTrailingSection: View {
    let agent: AgentInfo
    let idleColor: Color

    var body: some View {
        HStack {
            idleTextIfNeeded
            trailingCostOrTokens
        }
    }

    @ViewBuilder
    private var idleTextIfNeeded: some View {
        if agent.isIdle {
            idleText
        }
    }

    private var idleText: some View {
        Text(agent.idleText).font(.caption2).foregroundStyle(idleColor)
    }

    @ViewBuilder
    private var trailingCostOrTokens: some View {
        if let tokensUsed = agent.tokensUsed, agent.source == .codex {
            tokensText(tokensUsed)
        } else {
            costText
        }
    }

    private func tokensText(_ tokensUsed: Int) -> some View {
        Text("\(tokensUsed.formatted(.number.notation(.compactName))) tok")
            .font(.caption2).fontWeight(.semibold).foregroundStyle(.orange)
    }

    private var costText: some View {
        Text(String(format: "$%.2f", agent.cost))
            .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
    }
}

#Preview {
    PopoverAgentTrailingSection(
        agent: AgentInfo(
            pid: 1, model: "Sonnet", agentName: "Preview", contextPercent: 40, contextWindow: 200_000,
            cost: 1.25, linesAdded: 10, linesRemoved: 2, workingDir: "/tmp", sessionID: "s",
            durationMs: 0, apiDurationMs: 0, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
        ),
        idleColor: .gray
    )
}
