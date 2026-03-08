import SwiftUI
import AppKit

/// A task item reconstructed from TaskCreate/TaskUpdate/TodoWrite tool calls.
struct TaskListItem: Identifiable {
    let id: String
    var content: String
    var status: String
    var activeForm: String
}

public struct LogViewerView: View {
    let agent: AgentInfo
    let target: LogTarget
    let settings: AppSettings
    var stickyHeader: Bool = false
    let onDismiss: () -> Void

    @State private var messages: [LogMessage] = []
    @State private var isLoading = true
    @State private var lastMtime: Date?
    @State private var showTaskPanel = true

    private let rowSpacing: CGFloat = 10

    private var fileURL: URL {
        LogParser.resolveURL(agent: agent, target: target)
    }

    private var title: String {
        switch target {
        case .parent: return agent.displayName
        case .subagent(let sub): return sub.model
        }
    }

    /// Fixed scroll height based on setting (popover only). Window mode fills available space.
    private var scrollHeight: CGFloat? {
        if settings.displayMode == .window { return nil }
        return CGFloat(settings.maxVisibleLogMessages) * 60
    }

    private var navFont: Font { settings.displayMode == .window ? .body : .caption }
    private var titleFont: Font { settings.displayMode == .window ? .title3 : .headline }

    /// Reconstruct task list by replaying TaskCreate/TaskUpdate/TodoWrite calls in order.
    private var taskList: [TaskListItem] {
        var tasks: [TaskListItem] = []
        var nextId = 1

        for msg in messages {
            for tc in msg.toolCalls {
                switch tc.data {
                case .todoWrite(let d):
                    // TodoWrite replaces the entire list
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

            Text(title)
                .font(titleFont)
                .lineLimit(1)

            Spacer()

            if !taskList.isEmpty {
                Button { showTaskPanel.toggle() } label: {
                    Image(systemName: showTaskPanel ? "checklist.checked" : "checklist")
                        .font(navFont)
                }
                .buttonStyle(.plain)
                .foregroundStyle(showTaskPanel ? .blue : .secondary)
                .help(showTaskPanel ? "Hide tasks" : "Show tasks")
            }

            Button {
                NSWorkspace.shared.open(fileURL)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(navFont)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .help("Open in default editor")
        }
    }

    public var body: some View {
        if stickyHeader {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    logHeader
                        .padding(.vertical, 8)
                    Divider()
                }
                .padding(.horizontal, 16)
                // Window mode: side-by-side log + task panel
                if showTaskPanel && !taskList.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        logContent
                        Divider()
                        taskPanelView
                            .frame(width: 200)
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
            if !stickyHeader && showTaskPanel && !taskList.isEmpty {
                taskPanelView
                Divider()
            }

            if isLoading && messages.isEmpty {
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
            } else if messages.isEmpty {
                Text("No messages found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: rowSpacing) {
                            ForEach(messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                    .frame(height: scrollHeight, alignment: .top)
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(16)
        .task {
            await loadMessages()
            isLoading = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await loadMessages()
            }
        }
    }

    private func loadMessages() async {
        let url = fileURL
        let cached = lastMtime

        let (msgs, mtime): ([LogMessage], Date?) = await Task.detached(priority: .utility) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let mtime = attrs?[.modificationDate] as? Date
            if let cached, let mtime, cached == mtime {
                return ([], mtime)
            }
            return (LogParser.parseMessages(at: url), mtime)
        }.value

        if let mtime { lastMtime = mtime }
        if !msgs.isEmpty { messages = msgs }
    }

    // MARK: - Message Rendering

    @ViewBuilder
    private func messageBubble(_ msg: LogMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Role header
            HStack(spacing: 4) {
                Circle()
                    .fill(msg.role == .user ? .green : .blue)
                    .frame(width: 6, height: 6)

                Text(roleLabel(msg))
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

    private func roleLabel(_ msg: LogMessage) -> String {
        switch msg.role {
        case .user: return "User"
        case .assistant:
            if let model = msg.model, !model.isEmpty {
                return ClaudeModel.from(modelID: model).displayName
            }
            return "Assistant"
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
        if !tc.data.hasDetail {
            // Non-expandable chip
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
                toolExpandedContent(tc.data)
            } label: {
                toolChipLabel(tc)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    @ViewBuilder
    private func toolExpandedContent(_ data: ToolData) -> some View {
        switch data {
        case .edit(let d):
            editDiffView(d)
        case .write(let d):
            writeDiffView(d)
        case .bash(let d):
            monoText(d.command)
        case .grep(let d):
            monoText("pattern: \(d.pattern)" + (d.path.isEmpty ? "" : "\npath: \(d.path)"))
        case .glob(let d):
            monoText("pattern: \(d.pattern)" + (d.path.isEmpty ? "" : "\npath: \(d.path)"))
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

    private func monoText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Task Panel

    private var taskPanelView: some View {
        let tasks = taskList
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
                                .frame(width: 12)
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
