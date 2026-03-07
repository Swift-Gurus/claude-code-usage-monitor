import SwiftUI

public struct PopoverView: View {
    public var data: UsageData
    public var agentTracker: AgentTracker
    public var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var installed = StatuslineInstaller.isInstalled
    @State private var installError = false
    @State private var selectedPeriod: String?
    @State private var showSettings = false
    @State private var selectedAgent: AgentInfo?

    // Colors that adapt to dark/light mode
    private var idleColor: Color { colorScheme == .dark ? Color(white: 0.7) : .gray }
    private var idleOpacity: Double { colorScheme == .dark ? 0.85 : 0.6 }
    private var addedColor: Color { colorScheme == .dark ? .green : Color(red: 0.1, green: 0.55, blue: 0.1) }
    private var removedColor: Color { colorScheme == .dark ? Color(red: 1.0, green: 0.4, blue: 0.4) : .red }

    public init(data: UsageData, agentTracker: AgentTracker, settings: AppSettings) {
        self.data = data
        self.agentTracker = agentTracker
        self.settings = settings
    }

    private func statsFor(_ label: String) -> PeriodStats {
        switch label {
        case "Today": return data.day
        case "Week": return data.week
        case "Month": return data.month
        default: return data.day
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showSettings {
                SettingsView(settings: settings) { showSettings = false }
            } else if let agent = selectedAgent {
                SubagentDetailView(agent: agent, agentTracker: agentTracker, settings: settings) { selectedAgent = nil }
            } else if let label = selectedPeriod {
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
            HStack {
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            periodTable

            Divider()

            if !workingAgents.isEmpty || !idleAgents.isEmpty {
                ForEach(groupedSources, id: \.source) { group in
                    sourceSection(group)
                }
            } else if settings.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).scaleEffect(0.8)
                    Text("Loading active agents...")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                Text("No active agents")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
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

    private func sortAgents(_ agents: [AgentInfo]) -> [AgentInfo] {
        switch settings.agentSortOrder {
        case .recentlyUpdated: return agents.sorted { $0.updatedAt > $1.updatedAt }
        case .cost: return agents.sorted { $0.cost > $1.cost }
        case .contextUsage: return agents.sorted { $0.contextPercent > $1.contextPercent }
        }
    }

    private var workingAgents: [AgentInfo] {
        sortAgents(agentTracker.activeAgents.filter { !$0.isIdle })
    }

    private var idleAgents: [AgentInfo] {
        sortAgents(agentTracker.activeAgents.filter(\.isIdle))
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
                    .foregroundStyle(agent.isIdle ? idleColor : .green)
                Text(agent.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                if agent.isIdle {
                    Text(agent.idleText)
                        .font(.caption2)
                        .foregroundStyle(idleColor)
                }
                Text(String(format: "$%.2f", agent.cost))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            // Row 2: context bar + duration
            HStack(spacing: 8) {
                contextBar(agent.contextPercent, contextWindow: agent.contextWindow)
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
                    Text("+\(agent.linesAdded.formatted(.number.notation(.compactName)))")
                        .foregroundStyle(addedColor)
                    Text("-\(agent.linesRemoved.formatted(.number.notation(.compactName)))")
                        .foregroundStyle(removedColor)
                }
                    .font(.caption2)
            }

        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        .opacity(agent.isIdle ? idleOpacity : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { selectedAgent = agent }
    }

    private func contextBar(_ pct: Int, contextWindow: Int = 0) -> some View {
        let color: Color = pct >= 90 ? .red : pct >= 70 ? .yellow : .green
        let millions = Double(contextWindow) / 1_000_000.0
        let windowLabel = contextWindow <= 0 ? ""
            : millions == Double(Int(millions)) ? "\(Int(millions))M"
            : String(format: "%.1fM", millions)
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
            Text(windowLabel.isEmpty ? "\(pct)%" : "\(pct)% · \(windowLabel)")
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
                    Text("+\(stats.linesAdded.formatted(.number.notation(.compactName)))")
                        .font(.caption)
                        .foregroundStyle(addedColor)
                    Text("-\(stats.linesRemoved.formatted(.number.notation(.compactName)))")
                        .font(.caption)
                        .foregroundStyle(removedColor)
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

    private func costCell(_ cost: Double, font: Font = .caption, weight: Font.Weight = .medium) -> some View {
        Text(String(format: "$%.2f", cost))
            .font(font).fontWeight(weight)
            .foregroundStyle(.orange)
            .frame(width: 64, alignment: .trailing)
    }

    private func addedCell(_ count: Int, font: Font = .caption2) -> some View {
        Text("+\(count.formatted(.number.notation(.compactName)))")
            .font(font).foregroundStyle(addedColor)
            .frame(width: 46, alignment: .trailing)
    }

    private func removedCell(_ count: Int, font: Font = .caption2) -> some View {
        Text("-\(count.formatted(.number.notation(.compactName)))")
            .font(font).foregroundStyle(removedColor)
            .frame(width: 40, alignment: .trailing)
    }

    private func linesCell(added: Int, removed: Int, font: Font = .caption2) -> some View {
        HStack(spacing: 0) {
            addedCell(added, font: font)
            removedCell(removed, font: font)
        }
    }


    private func sourceBreakdown(name: String, icon: String, source: SourceStats) -> some View {
        let models = source.byModel.sorted { $0.value.cost > $1.value.cost }
        let subModels = source.subagentsByModel.sorted { $0.value.cost > $1.value.cost }
        let subTotal = source.subagentsByModel.values.reduce(0.0) { $0 + $1.cost }
        let subLA = source.subagentsByModel.values.reduce(0) { $0 + $1.linesAdded }
        let subLR = source.subagentsByModel.values.reduce(0) { $0 + $1.linesRemoved }

        return VStack(alignment: .leading, spacing: 5) {
            // Source header
            HStack(spacing: 0) {
                Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
                Text(" \(name)").font(.subheadline).fontWeight(.medium)
                Spacer(minLength: 2)
                addedCell(source.total.linesAdded, font: .caption)
                removedCell(source.total.linesRemoved, font: .caption)
                costCell(source.total.cost, font: .subheadline, weight: .semibold)
            }

            // Model rows
            ForEach(models, id: \.key) { model, stats in
                HStack(spacing: 0) {
                    Text(model).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 2)
                    addedCell(stats.linesAdded)
                    removedCell(stats.linesRemoved)
                    costCell(stats.cost)
                }
                .padding(.leading, 20)
            }

            if source.byModel.isEmpty && source.total.cost > 0 {
                Text("Model breakdown not available for older sessions")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.leading, 20)
            }

            // Subagents subsection
            if !source.subagentsByModel.isEmpty {
                HStack(spacing: 0) {
                    Image(systemName: "arrow.turn.down.right").font(.caption2).foregroundStyle(.secondary)
                    Text(" Subagents").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    addedCell(subLA)
                    removedCell(subLR)
                    costCell(subTotal)
                }
                .padding(.leading, 8)
                .padding(.top, 2)

                ForEach(subModels, id: \.key) { model, stats in
                    HStack(spacing: 0) {
                        Text(model).font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.tail)
                        Spacer(minLength: 2)
                        addedCell(stats.linesAdded)
                        removedCell(stats.linesRemoved)
                        costCell(stats.cost, font: .caption2)
                    }
                    .padding(.leading, 28)
                }
            }
        }
    }
}
