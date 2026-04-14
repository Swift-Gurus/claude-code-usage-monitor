import SwiftUI

private struct SubagentRowsLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let heights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        let total = heights.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1))
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for subview in subviews {
            let h = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                proposal: ProposedViewSize(width: bounds.width, height: h)
            )
            y += h + spacing
        }
    }
}

private struct RowHeightsKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/**
 solid-name: SubagentDetailState
 solid-category: abstraction
 solid-description: Contract for the read-only state that SubagentDetailView observes. Provides subagent list, parent tool counts, and sorted subagent computation.
 */
protocol SubagentDetailState: Observable {
    var subagents: [SubagentInfo] { get }
    var parentTools: [String: Int] { get }
    func sortedSubagents(by order: SubagentSortOrder) -> [SubagentInfo]
}

/**
 solid-name: SubagentDetailActions
 solid-category: abstraction
 solid-description: Contract for actions that SubagentDetailView can trigger. Provides data loading and polling lifecycle.
 */
protocol SubagentDetailActions {
    func load() async
    func startPolling() async
}

/**
 solid-name: SubagentParsing
 solid-category: abstraction
 solid-description: Contract for parsing subagent metadata and details from JSONL files. Enables testability of subagent detail loading without real file I/O.
 */
protocol SubagentParsing {
    func parseSubagentMeta(sessionID: String, workingDir: String, projectsDir: URL) -> [String: JSONLParser.SubagentMeta]
    func parseSubagentDetails(in dir: URL, meta: [String: JSONLParser.SubagentMeta]) -> [SubagentInfo]
}

/**
 solid-name: DefaultSubagentParser
 solid-category: utility
 solid-description: Production default for SubagentParsing. Delegates to JSONLParser's static subagent parsing APIs for dependency injection.
 */
struct DefaultSubagentParser: SubagentParsing {
    func parseSubagentMeta(sessionID: String, workingDir: String, projectsDir: URL) -> [String: JSONLParser.SubagentMeta] {
        JSONLParser.parseSubagentMeta(sessionID: sessionID, workingDir: workingDir, projectsDir: projectsDir)
    }

    func parseSubagentDetails(in dir: URL, meta: [String: JSONLParser.SubagentMeta]) -> [SubagentInfo] {
        JSONLParser.parseSubagentDetails(in: dir, meta: meta)
    }
}

/**
 solid-name: SubagentDetailViewModel
 solid-category: viewmodel
 solid-stack: [structured-concurrency]
 solid-description: ViewModel for SubagentDetailView. Owns subagent data loading from pre-written JSON files or JSONL fallback parsing, parent tool count loading, sorting, and polling. All data-fetching and transformation logic lives here.
 */
@Observable
final class SubagentDetailViewModel: SubagentDetailState, SubagentDetailActions {
    private(set) var subagents: [SubagentInfo] = []
    private(set) var parentTools: [String: Int] = [:]

    private let agent: AgentInfo
    private let settings: AppSettings
    private let pathEncoder: SessionPathEncoding
    private let subagentParser: SubagentParsing

    init(
        agent: AgentInfo,
        settings: AppSettings,
        pathEncoder: SessionPathEncoding = SessionPathEncoderAdapter(),
        subagentParser: SubagentParsing = DefaultSubagentParser()
    ) {
        self.agent = agent
        self.settings = settings
        self.pathEncoder = pathEncoder
        self.subagentParser = subagentParser
    }

    func sortedSubagents(by order: SubagentSortOrder) -> [SubagentInfo] {
        switch order {
        case .recent:
            return subagents.sorted { $0.lastModified > $1.lastModified }
        case .cost:
            return subagents.sorted { $0.cost > $1.cost }
        case .context:
            return subagents.sorted { $0.lastInputTokens > $1.lastInputTokens }
        case .name:
            return subagents.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    func load() async {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())

        let base = URL(fileURLWithPath: agent.claudeDir).appendingPathComponent("usage")
        let usageDir: URL
        switch agent.source {
        case .cli: usageDir = base
        case .commander: usageDir = base.appendingPathComponent("commander")
        }

        let dir = usageDir.appendingPathComponent(today)
        let pid = agent.pid
        let sessionID = agent.sessionID
        let workingDir = agent.workingDir
        let projectsDir = agent.projectsDir
        let encoder = pathEncoder
        let parser = subagentParser

        let (details, tools) = await Task.detached(priority: .utility) {
            var details = (try? Data(contentsOf: dir.appendingPathComponent("\(pid).subagent-details.json")))
                .flatMap { try? JSONDecoder().decode([SubagentInfo].self, from: $0) } ?? []
            let tools = (try? Data(contentsOf: dir.appendingPathComponent("\(pid).parent-tools.json")))
                .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]

            if details.isEmpty && !sessionID.isEmpty {
                let encoded = encoder.encodeProjectPath(workingDir)
                let subagentsDir = projectsDir
                    .appendingPathComponent(encoded)
                    .appendingPathComponent(sessionID)
                    .appendingPathComponent("subagents")
                let meta = parser.parseSubagentMeta(sessionID: sessionID, workingDir: workingDir, projectsDir: projectsDir)
                details = parser.parseSubagentDetails(in: subagentsDir, meta: meta)
            }

            return (details, tools)
        }.value

        if !details.isEmpty { subagents = details }
        if !tools.isEmpty { parentTools = tools }
    }

    func startPolling() async {
        await poll(interval: .seconds(2)) { [weak self] in
            await self?.load()
        }
    }
}

/**
 solid-name: ToolBadgeView
 solid-category: view-component
 solid-stack: [swiftui]
 solid-description: Reusable compact badge displaying a tool name with optional count. Used in both parent tool usage and subagent row tool lists.
 */
private struct ToolBadgeView: View {
    let tool: String
    let count: Int

    var body: some View {
        Text(count > 1 ? "\(tool) (\(count))" : tool)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }
}

/**
 solid-name: SubagentRowView
 solid-category: view-component
 solid-stack: [swiftui]
 solid-description: Renders a single subagent row with model name, lines added/removed, cost, description, context usage progress bar, and tool badges. Extracted from SubagentDetailView for reduced nesting and reusability.
 */
private struct SubagentRowView: View {
    let sub: SubagentInfo
    let contextBudget: SubagentContextBudget

    private var contextPct: Int {
        min(100, Int(Double(sub.lastInputTokens) / Double(contextBudget.tokens) * 100))
    }

    private var ctxColor: Color {
        contextPct >= 90 ? .red : contextPct >= 70 ? .yellow : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            descriptionRows
            progressRow
            toolBadges
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private var headerRow: some View {
        HStack {
            Text(sub.model).font(.caption).fontWeight(.medium).lineLimit(1)
            Spacer(minLength: 4)
            Text("+\(sub.linesAdded)").font(.caption2).foregroundStyle(.green)
                .frame(minWidth: 36, alignment: .trailing)
            Text("-\(sub.linesRemoved)").font(.caption2).foregroundStyle(.red)
                .frame(minWidth: 32, alignment: .trailing)
            Text(String(format: "$%.2f", sub.cost))
                .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
                .frame(minWidth: 48, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var descriptionRows: some View {
        if !sub.description.isEmpty {
            Text(sub.description)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        if !sub.subagentType.isEmpty {
            Text(sub.subagentType)
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private var progressRow: some View {
        ContextProgressBar(
            contextPercent: contextPct,
            label: "of \(contextBudget.label)"
        )
    }

    @ViewBuilder
    private var toolBadges: some View {
        if !sub.toolCounts.isEmpty {
            let sorted = sub.toolCounts.sorted { $0.value > $1.value }
            FlowLayout(spacing: 4, maxLines: 5) {
                ForEach(sorted, id: \.key) { tool, count in
                    ToolBadgeView(tool: tool, count: count)
                }
            }
        }
    }
}

/**
 solid-name: SubagentDetailView
 solid-category: screen
 solid-stack: [swiftui]
 solid-description: Full-screen detail view for a Claude Code session's subagents. Shows agent summary, parent tool usage, and scrollable subagent rows with context usage, cost, and tool badges. Delegates data loading to a generic ViewModel. Tapping a subagent opens LogViewerView for that subagent's logs.
 */
struct SubagentDetailView<VM: SubagentDetailState & SubagentDetailActions>: View {
    let agent: AgentInfo
    let agentTracker: AgentTracker
    let settings: AppSettings
    var sessionManager: SessionManager?
    let vm: VM
    let onDismiss: () -> Void

    @State private var rowHeights: [Int: CGFloat] = [:]
    @State private var logTarget: LogTarget?

    private let rowSpacing: CGFloat = 6

    private var viewportHeight: CGFloat? {
        if settings.displayMode == .window { return nil }
        let n = min(vm.subagents.count, settings.maxVisibleSubagents)
        guard rowHeights.count >= n else { return nil }
        let h = (0..<n).compactMap { rowHeights[$0] }.reduce(0, +)
        return h + rowSpacing * CGFloat(max(0, n - 1))
    }

    var body: some View {
        if let target = logTarget, settings.displayMode == .window {
            LogViewerView(agent: agent, target: target, settings: settings, sessionManager: sessionManager, stickyHeader: true, onStop: onDismiss, vm: LogViewerViewModel(agent: agent, target: target)) { logTarget = nil }
        } else if let target = logTarget {
            LogViewerView(agent: agent, target: target, settings: settings, sessionManager: sessionManager, onStop: onDismiss, vm: LogViewerViewModel(agent: agent, target: target)) { logTarget = nil }
        } else if settings.displayMode == .window {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    detailHeader
                        .padding(.vertical, 8)
                    Divider()
                }
                .padding(.horizontal, 16)
                ScrollView {
                    detailContent
                }
                .scrollIndicators(.visible)
            }
        } else {
            detailContent
        }
    }

    private var navFont: Font { settings.displayMode == .window ? .body : .caption }
    private var titleFont: Font { settings.displayMode == .window ? .title3 : .headline }

    private var detailHeader: some View {
        HStack {
            Button { onDismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(navFont)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            Spacer()
            Text(agent.displayName).font(titleFont)
            if !agent.sessionID.isEmpty {
                Button { logTarget = .parent } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(navFont)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .help("View session logs")
            }
        }
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if settings.displayMode == .popover {
                detailHeader
                Divider()
            }

            let subTotal = vm.subagents.reduce(0.0) { $0 + $1.cost }

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.shortDir).font(.caption).foregroundStyle(.secondary)
                        Text(agent.durationText).font(.caption2).foregroundStyle(.tertiary)
                        HStack(spacing: 6) {
                            Text("+\(agent.linesAdded.formatted(.number.notation(.compactName)))")
                                .font(.caption2).foregroundStyle(.green)
                            Text("-\(agent.linesRemoved.formatted(.number.notation(.compactName)))")
                                .font(.caption2).foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .top, spacing: 4) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total").font(.caption2).foregroundStyle(.tertiary)
                            if subTotal > 0 {
                                Text("Subagents").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "$%.2f", agent.cost))
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
                            if subTotal > 0 {
                                Text(String(format: "$%.2f", subTotal))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .gridColumnAlignment(.trailing)
                }

                if agent.contextPercent > 0 {
                    GridRow {
                        ContextProgressBar(
                            contextPercent: agent.contextPercent,
                            label: agent.contextWindowText.isEmpty ? "" : "· \(agent.contextWindowText)"
                        )
                        .gridCellColumns(2)
                    }
                }
            }

            if !vm.parentTools.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tools Used").font(.subheadline).fontWeight(.medium)
                    let sorted = vm.parentTools.sorted { $0.value > $1.value }
                    FlowLayout(spacing: 4, maxLines: 5) {
                        ForEach(sorted, id: \.key) { tool, count in
                            ToolBadgeView(tool: tool, count: count)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Text("Subagents").font(.subheadline).fontWeight(.medium)
                if !vm.subagents.isEmpty {
                    Text("\(vm.subagents.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                Spacer()
                Text("Budget: \(settings.subagentContextBudget.label)")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if vm.subagents.isEmpty {
                Text("No subagents recorded for this session")
                    .font(.caption).foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: rowSpacing) {
                        ForEach(Array(vm.sortedSubagents(by: settings.subagentSortOrder).enumerated()), id: \.element.id) { idx, sub in
                            SubagentRowView(sub: sub, contextBudget: settings.subagentContextBudget)
                                .contentShape(Rectangle())
                                .onTapGesture { logTarget = .subagent(sub) }
                                .background(GeometryReader { geo in
                                    Color.clear.preference(
                                        key: RowHeightsKey.self,
                                        value: [idx: geo.size.height]
                                    )
                                })
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(height: viewportHeight)
                .onPreferenceChange(RowHeightsKey.self) { heights in
                    rowHeights = heights
                }
            }
        }
        .padding(16)
        .task {
            await vm.load()
            await vm.startPolling()
        }
    }
}
