import SwiftUI

/// Folder path, branch/worktree tag, and source badge — the leading half of an agent
/// row's detail line.
struct PopoverAgentTagsSection: View {
    let agent: AgentInfo

    var body: some View {
        HStack {
            folderLabel
            branchOrWorktreeTag
            sourceBadge
        }
    }

    private var folderLabel: some View {
        Label(agent.shortDir, systemImage: "folder")
            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
    }

    @ViewBuilder
    private var branchOrWorktreeTag: some View {
        if !agent.branch.isEmpty {
            HookStatusBadge(label: agent.branch, color: .cyan)
        } else if !agent.worktreeName.isEmpty {
            HookStatusBadge(label: agent.worktreeName, color: .cyan)
        }
    }

    private var sourceBadge: some View {
        let source = PopoverSourceLabel(source: agent.source)
        return HookStatusBadge(label: source.text, color: source.color)
    }
}

#Preview {
    PopoverAgentTagsSection(
        agent: AgentInfo(
            pid: 1, model: "Sonnet", agentName: "Preview", contextPercent: 40, contextWindow: 200_000,
            cost: 1.25, linesAdded: 10, linesRemoved: 2, workingDir: "/tmp", sessionID: "s",
            durationMs: 0, apiDurationMs: 0, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
        )
    )
}
