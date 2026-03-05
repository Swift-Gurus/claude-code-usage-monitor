import SwiftUI

struct PopoverView: View {
    var data: UsageData
    var agentTracker: AgentTracker
    @State private var installed = StatuslineInstaller.isInstalled
    @State private var installError = false
    @State private var selectedPeriod: String?

    private func statsFor(_ label: String) -> PeriodStats {
        switch label {
        case "Today": return data.day
        case "Week": return data.week
        case "Month": return data.month
        default: return data.day
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let label = selectedPeriod {
                detailView(label: label, stats: statsFor(label))
            } else {
                mainView
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - Main View

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude Usage")
                .font(.headline)

            Divider()

            periodTable

            if !workingAgents.isEmpty || !idleAgents.isEmpty {
                ForEach(groupedSources, id: \.source) { group in
                    Divider()
                    sourceSection(group)
                }
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
    }

    // MARK: - Agents

    private var workingAgents: [AgentInfo] {
        agentTracker.activeAgents.filter { !$0.isIdle }.sorted { $0.cost > $1.cost }
    }

    private var idleAgents: [AgentInfo] {
        agentTracker.activeAgents.filter(\.isIdle).sorted { $0.cost > $1.cost }
    }

    private struct SourceGroup {
        let source: AgentSource
        let active: [AgentInfo]
        let idle: [AgentInfo]
    }

    private var groupedSources: [SourceGroup] {
        let sources: [AgentSource] = [.cli, .commander]
        return sources.compactMap { source in
            let active = workingAgents.filter { $0.source == source }
            let idle = idleAgents.filter { $0.source == source }
            guard !active.isEmpty || !idle.isEmpty else { return nil }
            return SourceGroup(source: source, active: active, idle: idle)
        }
    }

    @ViewBuilder
    private func sourceSection(_ group: SourceGroup) -> some View {
        HStack {
            Image(systemName: group.source == .cli ? "terminal" : "app.connected.to.app.below.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(group.source.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text("\(group.active.count + group.idle.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if !group.active.isEmpty {
            ForEach(group.active) { agent in
                agentRow(agent)
            }
        }

        if !group.idle.isEmpty {
            ForEach(group.idle) { agent in
                agentRow(agent)
            }
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

    // MARK: - Period Stats Table

    private var periodTable: some View {
        let rows: [(String, PeriodStats)] = [
            ("Today", data.day),
            ("Week", data.week),
            ("Month", data.month)
        ]

        return Grid(alignment: .trailing, verticalSpacing: 8) {
            GridRow {
                Spacer()
                    .gridColumnAlignment(.leading)
                Text("Cost")
                Text("+Lines")
                Text("-Lines")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            ForEach(rows, id: \.0) { label, stats in
                GridRow {
                    HStack(spacing: 4) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "$%.2f", stats.cost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Text("+\(stats.linesAdded)")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("-\(stats.linesRemoved)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedPeriod = label }
            }
        }
    }

    // MARK: - Detail View

    private func detailView(label: String, stats: PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with back button
            HStack {
                Button {
                    selectedPeriod = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                Text("\(label) Breakdown")
                    .font(.headline)
            }

            Divider()

            // Summary row
            HStack {
                Text("Total")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "$%.2f", stats.cost))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            // Source breakdowns
            let sources: [(String, String, SourceStats)] = [
                ("CLI", "terminal", stats.cli),
                ("Commander", "app.connected.to.app.below.fill", stats.commander)
            ]

            ForEach(sources.filter { $0.2.total.cost > 0 || $0.2.total.linesAdded > 0 }, id: \.0) { name, icon, source in
                Divider()
                sourceBreakdown(name: name, icon: icon, source: source)
            }
        }
    }

    private func sourceBreakdown(name: String, icon: String, source: SourceStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Source header
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "$%.2f", source.total.cost))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                Text("+\(source.total.linesAdded)")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("-\(source.total.linesRemoved)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Model rows (indented)
            let models = source.byModel.sorted { $0.value.cost > $1.value.cost }
            ForEach(models, id: \.key) { model, stats in
                HStack {
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "$%.2f", stats.cost))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    Text("+\(stats.linesAdded)")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("-\(stats.linesRemoved)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                .padding(.leading, 20)
            }

            // If no model data, show note
            if source.byModel.isEmpty && source.total.cost > 0 {
                Text("Model breakdown not available for older sessions")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 20)
            }
        }
    }
}
