import SwiftUI
import AppKit

/**
 solid-name: TaskListItem
 solid-category: model
 solid-description: A task item reconstructed from TaskCreate/TaskUpdate/TodoWrite tool calls in JSONL logs. Used in both log viewer and subagent detail views to display task progress.
 */
struct TaskListItem: Identifiable {
    let id: String
    var content: String
    var status: String
    var activeForm: String
}

/**
 solid-name: LogViewerState
 solid-category: abstraction
 solid-description: Contract for the read-only state that LogViewerView observes. Provides messages, loading state, task list, tool result lookup, pending prompt, file URL, and role label formatting.
 */
protocol LogViewerState: Observable {
    var messages: [LogMessage] { get }
    var isLoading: Bool { get }
    var taskList: [TaskListItem] { get }
    var toolResultLookup: [String: String] { get }
    var pendingPrompt: LogToolCall? { get }
    var fileURL: URL { get }
    func roleLabel(_ msg: LogMessage) -> String
}

/**
 solid-name: LogViewerActions
 solid-category: abstraction
 solid-description: Contract for actions that LogViewerView can trigger. Provides message loading and polling lifecycle methods.
 */
protocol LogViewerActions {
    func loadMessages() async
    func startPolling() async
}

/**
 solid-name: LogMessageParsing
 solid-category: abstraction
 solid-description: Contract for parsing JSONL files into display-ready LogMessage arrays. Enables testability of log viewer without real file I/O.
 */
protocol LogMessageParsing {
    func parseMessages(at url: URL) -> [LogMessage]
}

/**
 solid-name: LogParserAdapter
 solid-category: utility
 solid-description: Adapts LogParser's static parseMessages API to the LogMessageParsing protocol for dependency injection.
 */
struct LogParserAdapter: LogMessageParsing {
    func parseMessages(at url: URL) -> [LogMessage] {
        LogParser.parseMessages(at: url)
    }
}

/**
 solid-name: LogViewerViewModel
 solid-category: viewmodel
 solid-stack: [structured-concurrency]
 solid-description: ViewModel for LogViewerView. Owns message loading, polling, task list reconstruction, tool result lookup, pending prompt detection, and model-to-display-name resolution. All data-fetching and transformation logic lives here, keeping the view pure.
 */
@Observable
final class LogViewerViewModel: LogViewerState, LogViewerActions {
    private(set) var messages: [LogMessage] = []
    private(set) var isLoading = true
    private var lastMtime: Date?

    private let agent: AgentInfo
    private let target: LogTarget
    private let parser: LogMessageParsing
    private let modelResolver: ModelResolving
    private let urlResolver: LogURLResolving
    private let fileSystem: FileSystemProviding

    init(
        agent: AgentInfo,
        target: LogTarget,
        parser: LogMessageParsing = LogParserAdapter(),
        modelResolver: ModelResolving = ClaudeModelAdapter(),
        urlResolver: LogURLResolving = LogURLResolver(),
        fileSystem: FileSystemProviding = FileManager.default
    ) {
        self.agent = agent
        self.target = target
        self.parser = parser
        self.modelResolver = modelResolver
        self.urlResolver = urlResolver
        self.fileSystem = fileSystem
    }

    var fileURL: URL {
        urlResolver.resolveURL(agent: agent, target: target)
    }

    var taskList: [TaskListItem] {
        var tasks: [TaskListItem] = []
        var nextId = 1

        for msg in messages {
            for tc in msg.toolCalls {
                switch tc.data {
                case .todoWrite(let d):
                    tasks = d.todos.enumerated().map { idx, item in
                        TaskListItem(id: "todo-\(idx)", content: item.content, status: item.status, activeForm: "")
                    }
                case .taskCreate(let d):
                    let id = "\(nextId)"
                    nextId += 1
                    tasks.append(TaskListItem(id: id, content: d.subject, status: "pending", activeForm: d.activeForm))
                case .taskUpdate(let d):
                    if let idx = tasks.firstIndex(where: { $0.id == d.taskId }) {
                        if !d.status.isEmpty {
                            tasks[idx].status = d.status
                        }
                    }
                default:
                    break
                }
            }
        }
        return tasks
    }

    var toolResultLookup: [String: String] {
        var lookup: [String: String] = [:]
        for msg in messages {
            for (tid, content) in msg.toolResultContents {
                lookup[tid] = content
            }
        }
        return lookup
    }

    var pendingPrompt: LogToolCall? {
        let resolvedIDs = Set(messages.flatMap(\.toolResultIDs))
        for msg in messages.reversed() where msg.role == .assistant {
            for tc in msg.toolCalls.reversed() {
                if !resolvedIDs.contains(tc.id) && tc.data.needsPrompt {
                    return tc
                }
            }
        }
        return nil
    }

    func roleLabel(_ msg: LogMessage) -> String {
        switch msg.role {
        case .user: return "User"
        case .assistant:
            if let model = msg.model, !model.isEmpty {
                return modelResolver.resolve(modelID: model).displayName
            }
            return "Assistant"
        }
    }

    func loadMessages() async {
        let url = fileURL
        let cached = lastMtime
        let fs = fileSystem

        let (msgs, mtime): ([LogMessage], Date?) = await Task.detached(priority: .utility) { [parser] in
            let attrs = try? fs.attributesOfItem(atPath: url.path)
            let mtime = attrs?[.modificationDate] as? Date
            if let cached, let mtime, cached == mtime {
                return ([], mtime)
            }
            return (parser.parseMessages(at: url), mtime)
        }.value

        if let mtime { lastMtime = mtime }
        if !msgs.isEmpty { messages = msgs }
        isLoading = false
    }

    func startPolling() async {
        await poll(interval: .seconds(2)) { [weak self] in
            await self?.loadMessages()
        }
    }
}

/**
 solid-name: StatusDot
 solid-category: view-component
 solid-description: Reusable 6x6 circular indicator dot used in log headers and message bubbles to show status via color.
 */
private struct StatusDot: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}

/**
 solid-name: LogViewerView
 solid-category: screen
 solid-stack: [swiftui]
 solid-description: Full-screen log viewer for Claude Code JSONL session logs. Displays messages as chat bubbles, tool call chips with expandable detail, task panel, and interactive prompts for PTY-attached sessions. Delegates all data loading and transformation to a generic ViewModel.
 */
struct LogViewerView<VM: LogViewerState & LogViewerActions>: View {
    let agent: AgentInfo
    let target: LogTarget
    let settings: AppSettings
    var sessionManager: SessionManager?
    var stickyHeader: Bool = false
    var onStop: (() -> Void)?
    var onOpenFile: (URL) -> Void = { NSWorkspace.shared.open($0) }
    let vm: VM
    let onDismiss: () -> Void

    @State private var showTaskPanel = true
    @State private var inputText = ""

    private let rowSpacing: CGFloat = 10

    private var bridge: TTYBridge? {
        sessionManager?.bridge(for: agent.pid)
    }

    private var canSendInput: Bool {
        guard case .parent = target else { return false }
        return bridge?.isAttached ?? false
    }

    private var isParentTarget: Bool {
        if case .parent = target { return true }
        return false
    }

    private var title: String {
        switch target {
        case .parent: return agent.displayName
        case .subagent(let sub): return sub.model
        }
    }

    private var scrollHeight: CGFloat? {
        if settings.displayMode == .window { return nil }
        return CGFloat(settings.maxVisibleLogMessages) * 60
    }

    private var navFont: Font { settings.displayMode == .window ? .body : .caption }
    private var titleFont: Font { settings.displayMode == .window ? .title3 : .headline }

    private var logHeader: some View {
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

            HStack(spacing: 4) {
                StatusDot(color: canSendInput ? .green : .gray)
                Text(title)
                    .font(titleFont)
                    .lineLimit(1)
            }

            Spacer()

            if !vm.taskList.isEmpty {
                Button { showTaskPanel.toggle() } label: {
                    Image(systemName: showTaskPanel ? "checklist.checked" : "checklist")
                        .font(navFont)
                }
                .buttonStyle(.plain)
                .foregroundStyle(showTaskPanel ? .blue : .secondary)
                .help(showTaskPanel ? "Hide tasks" : "Show tasks")
            }

            if canSendInput {
                Button {
                    bridge?.detach()
                    sessionManager?.sessions.removeValue(forKey: agent.pid)
                    onStop?()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(navFont)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("Stop session")
            }

            Button {
                onOpenFile(vm.fileURL)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(navFont)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .help("Open in default editor")
        }
    }

    var body: some View {
        if stickyHeader {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    logHeader
                        .padding(.vertical, 8)
                    Divider()
                }
                .padding(.horizontal, 16)
                // Window mode: side-by-side log + task panel
                if showTaskPanel && !vm.taskList.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        logContent
                        Divider()
                        taskPanelView
                            .frame(minWidth: 160, idealWidth: 200, maxWidth: 280)
                    }
                } else {
                    logContent
                }
            }
        } else {
            logContent
        }
    }

    private var logContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !stickyHeader {
                logHeader
                Divider()
            }

            // Popover mode: inline task panel
            if !stickyHeader && showTaskPanel && !vm.taskList.isEmpty {
                taskPanelView
                Divider()
            }

            if vm.isLoading && vm.messages.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading logs...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if vm.messages.isEmpty {
                Text("No messages found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: rowSpacing) {
                            ForEach(vm.messages.filter { !$0.textContent.isEmpty || !$0.toolCalls.isEmpty || $0.thinking != nil }) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                    .frame(height: scrollHeight, alignment: .top)
                    .onChange(of: vm.messages.count) { _, _ in
                        if let last = vm.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = vm.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input field — hidden when modal prompt is active
            if canSendInput && vm.pendingPrompt == nil {
                Divider()
                inputField
            }
        }
        .padding(16)
        .overlay {
            if canSendInput, let pending = vm.pendingPrompt {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    promptView(pending)
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 8)
                        .padding(16)
                }
            }
        }
        .task {
            if let bridge {
                bridge.onActivity = {
                    Task { await vm.loadMessages() }
                }
            }

            await vm.loadMessages()
            await vm.startPolling()
        }
    }

    // MARK: - Message Rendering

    @ViewBuilder
    private func messageBubble(_ msg: LogMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Role header
            HStack(spacing: 4) {
                StatusDot(color: msg.role == .user ? .green : .blue)

                Text(vm.roleLabel(msg))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if let ts = msg.timestamp {
                    Text(ts, format: .dateTime.hour().minute().second())
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            // Thinking block (collapsible)
            if let thinking = msg.thinking {
                ExpandableSection(
                    expanded: settings.expandThinking,
                    tintColor: .purple.opacity(0.8)
                ) {
                    Text(thinking)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                            .font(.system(size: 9))
                        Text("Thinking")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.purple.opacity(0.8))
                }
            }

            // Content bubble
            if msg.role == .user, let fullText = msg.textContent.first, fullText.count > 120 {
                // Long user messages (e.g. subagent system prompts) — collapsible
                let firstLine = String(fullText.prefix(100)).components(separatedBy: "\n").first ?? String(fullText.prefix(100))
                ExpandableSection(
                    expanded: false,
                    tintColor: .green.opacity(0.7)
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(msg.textContent.enumerated()), id: \.offset) { _, text in
                            Text(text)
                                .font(.system(size: 11))
                                .textSelection(.enabled)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                } label: {
                    Text(firstLine + "...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    // Text blocks
                    ForEach(Array(msg.textContent.enumerated()), id: \.offset) { _, text in
                        Text(text)
                            .font(.system(size: 11))
                            .textSelection(.enabled)
                    }

                    // Tool calls
                    if !msg.toolCalls.isEmpty {
                        ForEach(msg.toolCalls) { tc in
                            toolCallChip(tc)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    msg.role == .user
                        ? Color.green.opacity(0.08)
                        : Color.blue.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
        }
    }

    // MARK: - Tool Chip Label

    private func toolChipLabel(_ tc: LogToolCall) -> some View {
        HStack(spacing: 4) {
            Text(tc.name)
                .font(.system(size: 10, weight: .medium))
            let summary = tc.data.summary
            if !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // MARK: - Tool Views

    @ViewBuilder
    private func toolCallChip(_ tc: LogToolCall) -> some View {
        let resultContent = vm.toolResultLookup[tc.id]
        if !tc.data.hasDetail && resultContent == nil {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.blue.opacity(0.7))
                toolChipLabel(tc)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
        } else {
            ExpandableSection(
                expanded: settings.expandTools,
                tintColor: .blue.opacity(0.7)
            ) {
                toolExpandedContent(tc.data, resultContent: resultContent)
            } label: {
                toolChipLabel(tc)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    @ViewBuilder
    private func toolExpandedContent(_ data: ToolData, resultContent: String? = nil) -> some View {
        switch data {
        case .edit(let d):
            editDiffView(d)
        case .write(let d):
            writeDiffView(d)
        case .read(let d):
            toolInputAndResult(d.filePath, resultContent: resultContent)
        case .bash(let d):
            toolInputAndResult(d.command, resultContent: resultContent)
        case .grep(let d):
            toolInputAndResult(
                "pattern: \(d.pattern)" + (d.path.isEmpty ? "" : "\npath: \(d.path)"),
                resultContent: resultContent
            )
        case .glob(let d):
            toolInputAndResult(
                "pattern: \(d.pattern)" + (d.path.isEmpty ? "" : "\npath: \(d.path)"),
                resultContent: resultContent
            )
        case .agent(let d):
            VStack(alignment: .leading, spacing: 4) {
                if !d.subagentType.isEmpty {
                    Text("type: \(d.subagentType)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if !d.prompt.isEmpty {
                    monoText(d.prompt)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
        case .taskCreate(let d):
            VStack(alignment: .leading, spacing: 2) {
                if !d.description.isEmpty {
                    Text(d.description).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if !d.activeForm.isEmpty {
                    Text(d.activeForm).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
                }
            }
            .textSelection(.enabled)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
        case .todoWrite(let d):
            todoChecklist(d.todos)
        case .webSearch(let d):
            monoText(d.query)
        case .webFetch(let d):
            monoText(d.url + (d.prompt.isEmpty ? "" : "\n\(d.prompt)"))
        case .askUserQuestion(let d):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(d.questions.enumerated()), id: \.offset) { _, q in
                    if !q.header.isEmpty {
                        Text(q.header).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    Text(q.question).font(.system(size: 10))
                    ForEach(Array(q.options.enumerated()), id: \.offset) { i, o in
                        Text("\(i + 1). \(o.label)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
        case .skill(let d):
            SkillToolExpandedContent(data: d)
        case .exitPlanMode(let d):
            monoText(String(d.plan.prefix(500)))
        case .other(let raw):
            monoText(raw.sorted(by: { $0.key < $1.key }).map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
        default:
            EmptyView()
        }
    }

    // MARK: - Custom Tool Renderers

    private func editDiffView(_ d: EditToolData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !d.filePath.isEmpty {
                Text(d.filePath)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 4)
            }
            if !d.oldString.isEmpty {
                ForEach(Array(d.oldString.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    Text("- \(line)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.1))
                }
            }
            if !d.newString.isEmpty {
                ForEach(Array(d.newString.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    Text("+ \(line)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.1))
                }
            }
        }
        .textSelection(.enabled)
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    private func writeDiffView(_ d: WriteToolData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !d.filePath.isEmpty {
                Text(d.filePath)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 4)
            }
            ForEach(Array(d.content.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                Text("+ \(line)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.1))
            }
        }
        .textSelection(.enabled)
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    private func todoChecklist(_ todos: [TodoWriteToolData.TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(todos.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    Image(systemName: todoIcon(item.status))
                        .font(.system(size: 10))
                        .foregroundStyle(todoColor(item.status))
                    Text(item.content)
                        .font(.system(size: 10))
                        .foregroundStyle(item.status == "completed" ? .secondary : .primary)
                        .strikethrough(item.status == "completed")
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    private func todoIcon(_ status: String) -> String {
        switch status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "circle.dotted.circle"
        default: return "circle"
        }
    }

    private func todoColor(_ status: String) -> Color {
        switch status {
        case "completed": return .green
        case "in_progress": return .orange
        default: return .secondary
        }
    }

    @State private var selectedOptionIdx: Int = 0
    @State private var promptToolID: String = ""

    // MARK: - Prompt UI

    @ViewBuilder
    private func promptView(_ tc: LogToolCall) -> some View {
        switch tc.data {
        case .askUserQuestion(let d):
            askUserQuestionPrompt(d, toolID: tc.id)
        case .exitPlanMode:
            planApprovalPrompt()
        case .bash, .edit, .write:
            permissionPrompt(tc)
        default:
            // Other tools that need prompt — show generic with Allow/Deny
            permissionPrompt(tc)
        }
    }

    private func permissionPrompt(_ tc: LogToolCall) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(tc.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(tc.data.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 8) {
                Button {
                    // "Yes" — first option, just Enter
                    bridge?.sendRaw("\r")
                } label: {
                    Text("Allow")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)

                Button {
                    // "Yes for this session" — second option, 1 down arrow + Enter
                    bridge?.sendRaw("\u{1b}[B")
                    bridge?.sendRaw("\r")
                } label: {
                    Text("Always")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)

                Button {
                    // "Reject" — Escape to dismiss
                    bridge?.sendRaw("\u{1b}")
                } label: {
                    Text("Deny")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func askUserQuestionPrompt(_ data: AskUserQuestionToolData, toolID: String) -> some View {
        let question = data.questions[0]
        // If this is a new prompt, the stored selection is stale — treat as 0
        let effectiveSelection = promptToolID == toolID ? selectedOptionIdx : 0

        return VStack(alignment: .leading, spacing: 8) {
            if !question.header.isEmpty {
                Text(question.header)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            Text(question.question)
                .font(.caption)
                .fontWeight(.medium)

            ForEach(Array(question.options.enumerated()), id: \.offset) { oIdx, option in
                Button {
                    selectedOptionIdx = oIdx
                    promptToolID = toolID
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: effectiveSelection == oIdx ? "circle.fill" : "circle")
                            .font(.system(size: 10))
                            .foregroundStyle(effectiveSelection == oIdx ? .blue : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                                .font(.caption)
                                .foregroundStyle(.primary)
                            if !option.description.isEmpty {
                                Text(option.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button {
                // Send each arrow key as a separate write so TUI receives them as individual key events
                let idx = promptToolID == toolID ? selectedOptionIdx : 0
                for _ in 0..<idx {
                    bridge?.sendRaw("\u{1b}[B")
                }
                bridge?.sendRaw("\r")
            } label: {
                Text("Submit")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func planApprovalPrompt() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("Plan ready for review")
                    .font(.caption)
                    .fontWeight(.medium)
            }

            HStack(spacing: 12) {
                Button {
                    // Approve — Enter to confirm default
                    bridge?.sendRaw("\r")
                } label: {
                    Text("Approve")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)

                Button {
                    // Reject — Escape to cancel
                    bridge?.sendRaw("\u{1b}")
                } label: {
                    Text("Reject")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Auto-sizing invisible text to drive height
                Text(inputText.isEmpty ? " " : inputText)
                    .font(.system(size: 12))
                    .padding(8)
                    .opacity(0)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $inputText)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(4)

                if inputText.isEmpty {
                    Text("Type a message...")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 36, maxHeight: 120)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))

            Button {
                sendInput()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(canSendInput && !inputText.isEmpty ? .blue : .gray)
            }
            .buttonStyle(.plain)
            .disabled(!canSendInput || inputText.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    private func sendInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        bridge?.send(text)
        inputText = ""
    }

    private func monoText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func toolInputAndResult(_ input: String, resultContent: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            monoText(input)
            if let result = resultContent, !result.isEmpty {
                ToolResultView(content: result)
            }
        }
    }

    // MARK: - Task Panel

    private var taskPanelView: some View {
        let tasks = vm.taskList
        let completed = tasks.filter { $0.status == "completed" }.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "checklist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tasks")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(completed)/\(tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            if !tasks.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green.opacity(0.2))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geo.size.width * CGFloat(completed) / CGFloat(tasks.count))
                    }
                }
                .frame(height: 4)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(tasks) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: taskIcon(item.status))
                                .font(.system(size: 10))
                                .foregroundStyle(taskColor(item.status))
                                .imageScale(.small)
                            Text(item.content)
                                .font(.system(size: 10))
                                .foregroundStyle(item.status == "completed" ? .secondary : .primary)
                                .strikethrough(item.status == "completed")
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding(10)
    }

    private func taskIcon(_ status: String) -> String {
        switch status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "circle.dotted.circle"
        case "deleted": return "xmark.circle"
        default: return "circle"
        }
    }

    private func taskColor(_ status: String) -> Color {
        switch status {
        case "completed": return .green
        case "in_progress": return .orange
        case "deleted": return .red
        default: return .secondary
        }
    }
}

// MARK: - ExpandableSection

/// A DisclosureGroup wrapper that takes an initial expanded state from settings.
private struct ExpandableSection<Content: View, Label: View>: View {
    @State private var isExpanded: Bool
    let tintColor: Color
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Label

    init(expanded: Bool, tintColor: Color,
         @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder label: @escaping () -> Label) {
        self._isExpanded = State(initialValue: expanded)
        self.tintColor = tintColor
        self.content = content
        self.label = label
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content()
        } label: {
            label()
        }
        .tint(tintColor)
    }
}

private struct ToolResultView: View {
    let content: String
    private let previewLineCount = 20

    private var lines: [String] { content.components(separatedBy: "\n") }
    private var isTruncated: Bool { lines.count > previewLineCount }
    private var preview: String { lines.prefix(previewLineCount).joined(separator: "\n") }

    @State private var showFull = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            resultLabel
            resultText
        }
    }

    private var resultLabel: some View {
        HStack(spacing: 4) {
            Text("Result")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            if isTruncated {
                Button { showFull.toggle() } label: {
                    Text(showFull ? "collapse" : "\(lines.count) lines")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var resultText: some View {
        Text(showFull || !isTruncated ? content : preview + "\n...")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
    }
}
