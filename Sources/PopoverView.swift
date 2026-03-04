import SwiftUI

struct PopoverView: View {
    var data: UsageData
    var agentTracker: AgentTracker
    @State private var installed = StatuslineInstaller.isInstalled
    @State private var installError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude Usage")
                .font(.headline)

            Divider()

            periodRow("Today", stats: data.day)
            periodRow("This Week", stats: data.week)
            periodRow("This Month", stats: data.month)

            if !agentTracker.activeAgents.isEmpty {
                Divider()
                agentsSection
            }

            Divider()

            HStack(spacing: 6) {
                Image(systemName: installed
                      ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(installed ? .green : .red)
                Text(installed
                     ? "Statusline active"
                     : installError ? "Install failed — check jq is installed"
                     : "Statusline not configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !installed {
                    Spacer()
                    Button("Install") {
                        let success = StatuslineInstaller.install()
                        installed = StatuslineInstaller.isInstalled
                        installError = !success
                    }
                    .font(.caption)
                }
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Agents

    @ViewBuilder
    private var agentsSection: some View {
        HStack {
            Text("Active Agents")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text("\(agentTracker.activeAgents.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        ForEach(agentTracker.activeAgents) { agent in
            agentRow(agent)
        }
    }

    private func agentRow(_ agent: AgentInfo) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: agent.isIdle ? "moon.zzz.fill" : "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(agent.isIdle ? .gray : .green)
                Text(agent.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                if agent.isIdle {
                    Text(agent.idleText)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                Text(String(format: "$%.2f", agent.cost))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                contextBadge(agent.contextPercent)
                Label(agent.shortDir, systemImage: "folder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .opacity(agent.isIdle ? 0.6 : 1.0)
    }

    private func contextBadge(_ pct: Int) -> some View {
        let color: Color = pct >= 90 ? .red : pct >= 70 ? .yellow : .green
        return Text("\(pct)%")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Period Stats

    private func periodRow(_ label: String, stats: PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "$%.2f", stats.cost))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                Label("+\(stats.linesAdded)", systemImage: "plus.circle.fill")
                    .foregroundStyle(.green)
                Label("-\(stats.linesRemoved)", systemImage: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .font(.caption)
        }
    }
}
