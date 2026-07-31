public enum ToolData {
    case edit(EditToolData)
    case write(WriteToolData)
    case read(ReadToolData)
    case bash(BashToolData)
    case grep(GrepToolData)
    case glob(GlobToolData)
    case agent(AgentToolData)
    case taskCreate(TaskCreateToolData)
    case taskUpdate(TaskUpdateToolData)
    case todoWrite(TodoWriteToolData)
    case skill(SkillToolData)
    case webSearch(WebSearchToolData)
    case webFetch(WebFetchToolData)
    case askUserQuestion(AskUserQuestionToolData)
    case exitPlanMode(ExitPlanModeToolData)
    case hook(HookToolData)
    case mcp(MCPToolData)
    case other(raw: [String: String])

    /// The hook payload for `.hook` cases, nil otherwise. Lets callers avoid pattern
    /// matching on the concrete case when they only care about hook data.
    public var hookData: HookToolData? {
        if case .hook(let d) = self { return d }
        return nil
    }

    /// Short display text for the chip label.
    public var summary: String {
        switch self {
        case .edit(let d): return d.filePath
        case .write(let d): return d.filePath
        case .read(let d):
            return d.filePath + (d.lineRange.map { " (\($0))" } ?? "")
        case .bash(let d):
            return d.description.isEmpty
                ? String(d.command.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
                : String(d.description.prefix(80))
        case .grep(let d): return d.pattern
        case .glob(let d): return d.pattern
        case .agent(let d): return String(d.description.prefix(80))
        case .taskCreate(let d): return d.subject
        case .taskUpdate(let d): return "#\(d.taskId) → \(d.status)"
        case .todoWrite(let d): return "\(d.todos.count) items"
        case .skill(let d): return d.name
        case .webSearch(let d): return d.query
        case .webFetch(let d): return d.url
        case .askUserQuestion(let d): return d.questions.first?.question ?? "Question"
        case .exitPlanMode: return "Plan ready for review"
        case .hook(let d):
            let statusTag: String
            switch d.status {
            case .progress: statusTag = " · started"
            case .success: statusTag = " · done"
            case .blockingError: statusTag = " · blocked"
            case .cancelled: statusTag = " · cancelled"
            case .systemMessage, .none: statusTag = ""
            }
            let cmd = d.command.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cmd.isEmpty {
                return "\(d.hookName)\(statusTag) · \(String(cmd.prefix(60)))"
            }
            if let ctx = d.context, !ctx.isEmpty {
                return "\(d.hookName)\(statusTag) · +\(ctx.count) chars"
            }
            return d.hookName + statusTag
        case .mcp(let d):
            return "\(d.serverName) · \(d.toolName)"
        case .other(let raw):
            return raw.sorted(by: { $0.key < $1.key }).first.map { String($0.value.prefix(80)) } ?? ""
        }
    }

    /// Whether this tool has expandable detail content.
    public var hasDetail: Bool {
        switch self {
        case .taskUpdate: return false
        default: return true
        }
    }

    /// Whether this tool needs an interactive prompt (permission or question).
    public var needsPrompt: Bool {
        switch self {
        case .bash, .edit, .write, .askUserQuestion, .exitPlanMode: return true
        default: return false
        }
    }
}
