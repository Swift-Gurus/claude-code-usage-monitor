import Foundation

// MARK: - Tool Data Types

public struct EditToolData {
    public let filePath: String
    public let oldString: String
    public let newString: String
    public let replaceAll: Bool
}

public struct WriteToolData {
    public let filePath: String
    public let content: String
}

public struct ReadToolData {
    public let filePath: String
}

public struct BashToolData {
    public let command: String
    public let description: String
}

public struct GrepToolData {
    public let pattern: String
    public let path: String
}

public struct GlobToolData {
    public let pattern: String
    public let path: String
}

public struct AgentToolData {
    public let description: String
    public let prompt: String
    public let subagentType: String
}

public struct TaskCreateToolData {
    public let subject: String
    public let description: String
    public let activeForm: String
}

public struct TaskUpdateToolData {
    public let taskId: String
    public let status: String
}

public struct TodoWriteToolData {
    public let todos: [TodoItem]

    public struct TodoItem {
        public let content: String
        public let status: String
    }
}

public struct SkillToolData {
    public let skill: String
    public let args: String
}

public struct WebSearchToolData {
    public let query: String
}

public struct WebFetchToolData {
    public let url: String
    public let prompt: String
}

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
    case other(raw: [String: String])

    /// Short display text for the chip label.
    public var summary: String {
        switch self {
        case .edit(let d): return d.filePath
        case .write(let d): return d.filePath
        case .read(let d): return d.filePath
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
        case .skill(let d): return d.skill
        case .webSearch(let d): return d.query
        case .webFetch(let d): return d.url
        case .other(let raw):
            return raw.sorted(by: { $0.key < $1.key }).first.map { String($0.value.prefix(80)) } ?? ""
        }
    }

    /// Whether this tool has expandable detail content.
    public var hasDetail: Bool {
        switch self {
        case .read, .skill, .taskUpdate: return false
        default: return true
        }
    }
}

// MARK: - Data Models

public struct LogMessage: Identifiable {
    public let id: String
    public let role: Role
    public let model: String?
    public let timestamp: Date?
    public let thinking: String?
    public let textContent: [String]
    public let toolCalls: [LogToolCall]

    public enum Role {
        case user, assistant
    }
}

public struct LogToolCall: Identifiable {
    public let id: String       // tool_use id from JSONL (for dedup)
    public let name: String
    public let data: ToolData
}

// MARK: - Log Target

public enum LogTarget: Equatable {
    case parent
    case subagent(SubagentInfo)

    public static func == (lhs: LogTarget, rhs: LogTarget) -> Bool {
        switch (lhs, rhs) {
        case (.parent, .parent): return true
        case (.subagent(let a), .subagent(let b)): return a.agentID == b.agentID
        default: return false
        }
    }
}

// MARK: - Parser

public enum LogParser {

    /// Parse a JSONL file into display-ready messages.
    /// Deduplicates assistant messages by message.id (last entry wins).
    /// User messages are kept in order.
    public static func parseMessages(at url: URL) -> [LogMessage] {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return [] }

        var result: [LogMessage] = []
        var assistantByID: [String: (index: Int, msg: LogMessage)] = [:]

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }

            let type = raw["type"] as? String ?? ""
            let ts = (raw["timestamp"] as? String).flatMap { timestampFormatter.date(from: $0) }

            guard let msg = raw["message"] as? [String: Any],
                  let contentArr = msg["content"] as? [[String: Any]]
            else {
                // User text messages without content array
                if type == "user", let msgDict = raw["message"] as? [String: Any],
                   let text = msgDict["content"] as? String, !text.isEmpty {
                    result.append(LogMessage(
                        id: "user-\(result.count)", role: .user, model: nil,
                        timestamp: ts, thinking: nil, textContent: [text], toolCalls: []
                    ))
                }
                continue
            }

            if type == "user" {
                let texts = contentArr.compactMap { item -> String? in
                    guard item["type"] as? String == "text" else { return nil }
                    return item["text"] as? String
                }.filter { !$0.isEmpty }
                guard !texts.isEmpty else { continue }
                result.append(LogMessage(
                    id: "user-\(result.count)", role: .user, model: nil,
                    timestamp: ts, thinking: nil, textContent: texts, toolCalls: []
                ))
            } else if type == "assistant" {
                let model = msg["model"] as? String
                var texts: [String] = []
                var thinkingParts: [String] = []
                var tools: [LogToolCall] = []

                for item in contentArr {
                    let itemType = item["type"] as? String ?? ""
                    switch itemType {
                    case "text":
                        if let t = item["text"] as? String, !t.isEmpty { texts.append(t) }
                    case "thinking":
                        if let t = item["thinking"] as? String, !t.isEmpty { thinkingParts.append(t) }
                    case "tool_use":
                        if let name = item["name"] as? String,
                           let input = item["input"] as? [String: Any] {
                            let toolId = item["id"] as? String ?? UUID().uuidString
                            let toolData = parseToolData(name: name, input: input)
                            tools.append(LogToolCall(id: toolId, name: name, data: toolData))
                        }
                    default: break
                    }
                }

                guard !texts.isEmpty || !tools.isEmpty || !thinkingParts.isEmpty else { continue }

                let msgID = msg["id"] as? String ?? "assistant-\(result.count)"
                let thinking = thinkingParts.isEmpty ? nil : thinkingParts.joined(separator: "\n\n")
                let logMsg = LogMessage(
                    id: msgID, role: .assistant, model: model,
                    timestamp: ts, thinking: thinking,
                    textContent: texts, toolCalls: tools
                )

                if let existing = assistantByID[msgID] {
                    let prev = existing.msg
                    // Merge tool calls: union by tool_use id (streaming sends one tool per entry)
                    var mergedTools = prev.toolCalls
                    let existingIds = Set(mergedTools.map(\.id))
                    for tc in logMsg.toolCalls where !existingIds.contains(tc.id) {
                        mergedTools.append(tc)
                    }
                    let merged = LogMessage(
                        id: msgID, role: .assistant,
                        model: logMsg.model ?? prev.model,
                        timestamp: logMsg.timestamp ?? prev.timestamp,
                        thinking: logMsg.thinking ?? prev.thinking,
                        textContent: logMsg.textContent.isEmpty ? prev.textContent : logMsg.textContent,
                        toolCalls: mergedTools
                    )
                    result[existing.index] = merged
                    assistantByID[msgID] = (existing.index, merged)
                } else {
                    assistantByID[msgID] = (result.count, logMsg)
                    result.append(logMsg)
                }
            }
        }

        return result
    }

    /// Resolve the JSONL file URL for a given agent and log target.
    public static func resolveURL(agent: AgentInfo, target: LogTarget) -> URL {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let encoded = SessionScanner.encodeProjectPath(agent.workingDir)

        switch target {
        case .parent:
            return projectsDir
                .appendingPathComponent(encoded)
                .appendingPathComponent("\(agent.sessionID).jsonl")
        case .subagent(let sub):
            return projectsDir
                .appendingPathComponent(encoded)
                .appendingPathComponent(agent.sessionID)
                .appendingPathComponent("subagents")
                .appendingPathComponent("\(sub.agentID).jsonl")
        }
    }

    // MARK: - Tool Data Parsing

    private static func parseToolData(name: String, input: [String: Any]) -> ToolData {
        let str = { (key: String) -> String in input[key] as? String ?? "" }

        switch name {
        case "Edit":
            return .edit(EditToolData(
                filePath: str("file_path"),
                oldString: str("old_string"),
                newString: str("new_string"),
                replaceAll: input["replace_all"] as? Bool ?? false
            ))
        case "Write":
            return .write(WriteToolData(filePath: str("file_path"), content: str("content")))
        case "Read":
            return .read(ReadToolData(filePath: str("file_path")))
        case "Bash":
            return .bash(BashToolData(command: str("command"), description: str("description")))
        case "Grep":
            return .grep(GrepToolData(pattern: str("pattern"), path: str("path")))
        case "Glob":
            return .glob(GlobToolData(pattern: str("pattern"), path: str("path")))
        case "Agent":
            return .agent(AgentToolData(
                description: str("description"), prompt: str("prompt"),
                subagentType: str("subagent_type")
            ))
        case "TaskCreate":
            return .taskCreate(TaskCreateToolData(
                subject: str("subject"), description: str("description"),
                activeForm: str("activeForm")
            ))
        case "TaskUpdate":
            return .taskUpdate(TaskUpdateToolData(taskId: str("taskId"), status: str("status")))
        case "TodoWrite":
            var items: [TodoWriteToolData.TodoItem] = []
            if let todos = input["todos"] as? [[String: Any]] {
                for todo in todos {
                    items.append(TodoWriteToolData.TodoItem(
                        content: todo["content"] as? String ?? "",
                        status: todo["status"] as? String ?? "pending"
                    ))
                }
            }
            return .todoWrite(TodoWriteToolData(todos: items))
        case "Skill":
            return .skill(SkillToolData(skill: str("skill"), args: str("args")))
        case "WebSearch":
            return .webSearch(WebSearchToolData(query: str("query")))
        case "WebFetch":
            return .webFetch(WebFetchToolData(url: str("url"), prompt: str("prompt")))
        default:
            // Capture all string values for unknown tools
            var raw: [String: String] = [:]
            for (key, val) in input {
                if let s = val as? String { raw[key] = s }
                else if let n = val as? NSNumber { raw[key] = n.stringValue }
                else if let arr = val as? [[String: Any]] {
                    let lines = arr.map { dict in
                        dict.sorted(by: { $0.key < $1.key })
                            .compactMap { k, v in (v as? String).map { "\(k): \($0)" } }
                            .joined(separator: ", ")
                    }
                    raw[key] = lines.joined(separator: "\n")
                }
            }
            return .other(raw: raw)
        }
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
