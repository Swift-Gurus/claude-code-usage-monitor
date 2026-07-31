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
 solid-description: Contract for managing and querying subagent session state.
 */
protocol SubagentDetailState: Observable {
    var subagents: [SubagentInfo] { get }
    var parentTools: [String: Int] { get }
    func sortedSubagents(by order: SubagentSortOrder) -> [SubagentInfo]
    func logTarget(for subagent: SubagentInfo) -> LogTarget
}

/**
 solid-name: SubagentDetailActions
 solid-category: abstraction
 solid-description: Contract for triggering subagent data refresh and observation cycles.
 */
protocol SubagentDetailActions {
    func load() async
    func startPolling() async
}

/**
 solid-name: SubagentParsing
 solid-category: abstraction
 solid-description: Contract for extracting subagent information from session sources.
 */
protocol SubagentParsing {
    func parseSubagentMeta(sessionID: String, workingDir: String, projectsDir: URL) -> [String: JSONLParser.SubagentMeta]
    func parseSubagentDetails(in dir: URL, meta: [String: JSONLParser.SubagentMeta], worktreeName: String) -> [SubagentInfo]
    func parseBareChildren(parentSessionID: String, in projectDir: URL) -> [SubagentInfo]
}

/**
 solid-name: DefaultSubagentParser
 solid-category: utility
 solid-description: Parses subagent metadata and session information from storage.
 */
struct DefaultSubagentParser: SubagentParsing {
    func parseSubagentMeta(sessionID: String, workingDir: String, projectsDir: URL) -> [String: JSONLParser.SubagentMeta] {
        JSONLParser.parseSubagentMeta(sessionID: sessionID, workingDir: workingDir, projectsDir: projectsDir)
    }

    func parseSubagentDetails(in dir: URL, meta: [String: JSONLParser.SubagentMeta], worktreeName: String) -> [SubagentInfo] {
        JSONLParser.parseSubagentDetails(in: dir, meta: meta, worktreeName: worktreeName)
    }

    func parseBareChildren(parentSessionID: String, in projectDir: URL) -> [SubagentInfo] {
        JSONLParser.parseBareChildren(parentSessionID: parentSessionID, in: projectDir)
    }
}

/**
 solid-name: SubagentDetailViewModel
 solid-category: viewmodel
 solid-stack: [structured-concurrency]
 solid-description: Manages subagent data loading, sorting, and polling for display.
 */
@Observable
final class SubagentDetailViewModel: SubagentDetailState, SubagentDetailActions {
    private(set) var subagents: [SubagentInfo] = []
    private(set) var parentTools: [String: Int] = [:]

    private let agent: AgentInfo
    private let settings: AppSettings
    private let pathEncoder: SessionPathEncoding
    private let subagentParser: SubagentParsing
    private let codexSessions: CodexSessionInspecting
    private var codexChildSessionsByID: [String: CodexSession] = [:]

    init(
        agent: AgentInfo,
        settings: AppSettings,
        pathEncoder: SessionPathEncoding = SessionPathEncoderAdapter(),
        subagentParser: SubagentParsing = DefaultSubagentParser(),
        codexSessions: CodexSessionInspecting = CodexSessionRepository()
    ) {
        self.agent = agent
        self.settings = settings
        self.pathEncoder = pathEncoder
        self.subagentParser = subagentParser
        self.codexSessions = codexSessions
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

    func logTarget(for subagent: SubagentInfo) -> LogTarget {
        if agent.source == .codex, let session = codexChildSessionsByID[subagent.agentID] {
            return .codexSession(session)
        }
        return .subagent(subagent)
    }

    func load() async {
        if agent.source == .codex {
            await loadCodexDetails()
            return
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())

        let base = URL(fileURLWithPath: agent.claudeDir).appendingPathComponent("usage")
        let usageDir: URL
        switch agent.source {
        case .cli, .desktop, .codex: usageDir = base
        case .commander: usageDir = base.appendingPathComponent("commander")
        }

        let dir = usageDir.appendingPathComponent(today)
        let pid = agent.pid
        let sessionID = agent.sessionID
        let workingDir = agent.workingDir
        let projectsDir = agent.projectsDir
        let parser = subagentParser

        let (details, tools) = await Task.detached(priority: .utility) {
            var details = (try? Data(contentsOf: dir.appendingPathComponent("\(pid).subagent-details.json")))
                .flatMap { try? JSONDecoder().decode([SubagentInfo].self, from: $0) } ?? []
            let tools = (try? Data(contentsOf: dir.appendingPathComponent("\(pid).parent-tools.json")))
                .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]

            if details.isEmpty && !sessionID.isEmpty {
                let meta = parser.parseSubagentMeta(sessionID: sessionID, workingDir: workingDir, projectsDir: projectsDir)
                // Check all subagent dirs (main + worktrees)
                let allDirs = SessionScanner.findSubagentDirs(
                    sessionID: sessionID,
                    workingDir: workingDir,
                    projectsDir: projectsDir
                )
                for (subDir, wtName) in allDirs {
                    details += parser.parseSubagentDetails(in: subDir, meta: meta, worktreeName: wtName ?? "")
                }
                // Include bare (hook/sdk-cli) sessions linked to this parent
                let encoded = SessionScanner.encodeProjectPath(workingDir)
                let projectDir = projectsDir.appendingPathComponent(encoded)
                details += parser.parseBareChildren(parentSessionID: sessionID, in: projectDir)
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

    private func loadCodexDetails() async {
        let sessions = codexSessions
        let threadID = agent.sessionID
        // SQLite queries and JSONL file I/O must not run on the main actor.
        let childSessions = await Task.detached(priority: .utility) {
            sessions.childSessions(parentThreadID: threadID, now: Date())
        }.value

        codexChildSessionsByID = Dictionary(uniqueKeysWithValues: childSessions.map { ($0.threadID, $0) })
        subagents = childSessions.map(makeCodexSubagent)
        parentTools = [:]
    }

    private func makeCodexSubagent(from session: CodexSession) -> SubagentInfo {
        let locationLabel = (session.cwd as NSString).lastPathComponent
        return SubagentInfo(
            agentID: session.threadID,
            model: session.model.isEmpty ? "Codex" : session.model,
            cost: 0,
            lastInputTokens: session.currentContextTokens,
            linesAdded: 0,
            linesRemoved: 0,
            toolCounts: [:],
            description: session.title,
            subagentType: locationLabel,
            contextWindow: session.contextWindow,
            lastModified: session.updatedAt.timeIntervalSince1970,
            worktreeName: "",
            sourceLabel: "Codex Task"
        )
    }
}

/**
 solid-name: ToolBadgeView
 solid-category: view-component
 solid-stack: [swiftui]
 solid-description: Displays a tool name with an optional usage count.
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
 solid-description: Displays a subagent's metrics and resource usage information.
 */
private struct SubagentRowView: View {
    let sub: SubagentInfo
    let contextBudget: SubagentContextBudget

    private var progressContextWindow: Int {
        sub.contextWindow > 0 ? sub.contextWindow : contextBudget.tokens
    }

    private var contextPct: Int {
        guard progressContextWindow > 0 else { return 0 }
        return min(100, Int(Double(sub.lastInputTokens) / Double(progressContextWindow) * 100))
    }

    private var progressLabel: String {
        if sub.contextWindow > 0 {
            let millions = Double(sub.contextWindow) / 1_000_000.0
            let label = millions == Double(Int(millions))
                ? "\(Int(millions))M"
                : String(format: "%.1fM", millions)
            return "· \(label)"
        }
        return "of \(contextBudget.label)"
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
            if !sub.sourceLabel.isEmpty {
                Text(sub.sourceLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            }
            if !sub.worktreeName.isEmpty {
                Text(sub.worktreeName)
                    .font(.system(size: 9))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            }
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
            label: progressLabel
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
 solid-description: Displays subagent session information and enables navigation to subagent logs.
 */
struct SubagentDetailView<VM: SubagentDetailState & SubagentDetailActions>: View {
    let agent: AgentInfo
    let agentTracker: AgentTracker
    let settings: AppSettings
    var sessionManager: SessionManager?
    @State var vm: VM
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

    private var logParser: LogMessageParsing {
        if agent.source == .codex {
            return CodexLogParser()
        }
        return LogParser()
    }

    var body: some View {
        if let target = logTarget, settings.displayMode == .window {
            LogViewerView(
                agent: agent,
                target: target,
                settings: settings,
                sessionManager: sessionManager,
                stickyHeader: true,
                onStop: onDismiss,
                vm: LogViewerViewModel(agent: agent, target: target, parser: logParser)
            ) { logTarget = nil }
        } else if let target = logTarget {
            LogViewerView(
                agent: agent,
                target: target,
                settings: settings,
                sessionManager: sessionManager,
                onStop: onDismiss,
                vm: LogViewerViewModel(agent: agent, target: target, parser: logParser)
            ) { logTarget = nil }
        } else {
            SessionDetailView(
                title: agent.displayName,
                settings: settings,
                openFileHelp: "View session logs",
                onDismiss: onDismiss,
                onOpenFile: agent.sessionID.isEmpty ? nil : { logTarget = .parent },
                summarySection: { summarySection },
                childSection: {
                    Group {
                        Divider()
                        childSection
                    }
                },
                logSection: { EmptyView() }
            )
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if agent.source == .codex {
            codexSummarySection
        } else {
            claudeSummarySection
        }
    }

    private var claudeSummarySection: some View {
        let subTotal = vm.subagents.reduce(0.0) { $0 + $1.cost }

        return Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
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

            if !vm.parentTools.isEmpty {
                GridRow {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tools Used").font(.subheadline).fontWeight(.medium)
                        let sorted = vm.parentTools.sorted { $0.value > $1.value }
                        FlowLayout(spacing: 4, maxLines: 5) {
                            ForEach(sorted, id: \.key) { tool, count in
                                ToolBadgeView(tool: tool, count: count)
                            }
                        }
                    }
                    .gridCellColumns(2)
                }
            }
        }
    }

    private var codexSummarySection: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
            GridRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text(agent.shortDir)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(agent.durationText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\((agent.tokensUsed ?? 0).formatted(.number.notation(.compactName))) tok")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Text(agent.model)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
    }

    private var childSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                                .onTapGesture { logTarget = vm.logTarget(for: sub) }
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
        .task {
            await vm.load()
            await vm.startPolling()
        }
    }
}
