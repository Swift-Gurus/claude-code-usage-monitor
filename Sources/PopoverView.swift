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

            if !workingAgents.isEmpty {
                Divider()
                agentSection("Active Agents", agents: workingAgents, icon: "circle.fill", color: .green)
            }

            if !idleAgents.isEmpty {
                Divider()
                agentSection("Idle Agents", agents: idleAgents, icon: "moon.zzz.fill", color: .gray)
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
        .frame(width: 320)
    }

    // MARK: - Agents

    private var workingAgents: [AgentInfo] {
        agentTracker.activeAgents.filter { !$0.isIdle }.sorted { $0.cost > $1.cost }
    }

    private var idleAgents: [AgentInfo] {
        agentTracker.activeAgents.filter(\.isIdle).sorted { $0.cost > $1.cost }
    }

    @ViewBuilder
    private func agentSection(_ title: String, agents: [AgentInfo], icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text("\(agents.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        ForEach(agents) { agent in
            agentRow(agent)
        }
    }

    private func agentRow(_ agent: AgentInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: name + cost
            HStack {
                Image(systemName: agent.isIdle ? "moon.zzz.fill" : "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(agent.isIdle ? .gray : .green)
                Text(agent.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                if agent.isIdle {
                    Text(agent.idleText)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                Text(String(format: "$%.2f", agent.cost))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            // Row 2: context bar + duration
            HStack(spacing: 8) {
                contextBar(agent.contextPercent)
                Label(agent.durationText, systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Row 3: folder + lines
            HStack {
                Label(agent.shortDir, systemImage: "folder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 6) {
                    Text("+\(agent.linesAdded)")
                        .foregroundStyle(.green)
                    Text("-\(agent.linesRemoved)")
                        .foregroundStyle(.red)
                }
                .font(.caption2)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        .opacity(agent.isIdle ? 0.6 : 1.0)
    }

    private func contextBar(_ pct: Int) -> some View {
        let color: Color = pct >= 90 ? .red : pct >= 70 ? .yellow : .green
        return HStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(pct, 100)) / 100)
                }
            }
            .frame(width: 60, height: 6)
            Text("\(pct)%")
                .font(.caption2)
                .foregroundStyle(color)
        }
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
