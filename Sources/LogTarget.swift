public enum LogTarget: Equatable {
    case parent
    case subagent(SubagentInfo)
    case codexSession(CodexSession)

    /// True for `.parent`, false otherwise. Centralizes the parent-check so callers
    /// don't need to pattern-match on the concrete case.
    public var isParent: Bool {
        if case .parent = self { return true }
        return false
    }

    public static func == (lhs: LogTarget, rhs: LogTarget) -> Bool {
        switch (lhs, rhs) {
        case (.parent, .parent): return true
        case (.subagent(let a), .subagent(let b)): return a.agentID == b.agentID
        case (.codexSession(let a), .codexSession(let b)): return a.threadID == b.threadID
        default: return false
        }
    }

    /// Display title for this target. `agentName` supplies the `.parent` case's title
    /// since a bare LogTarget has no agent context of its own.
    public func displayTitle(agentName: String) -> String {
        switch self {
        case .parent: return agentName
        case .subagent(let sub): return sub.model
        case .codexSession(let session): return session.title.isEmpty ? session.model : session.title
        }
    }
}
