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

public struct AskUserQuestionToolData {
    public let questions: [Question]

    public struct Question {
        public let question: String
        public let header: String
        public let options: [Option]
        public let multiSelect: Bool
    }

    public struct Option {
        public let label: String
        public let description: String
    }
}

public struct ExitPlanModeToolData {
    public let plan: String
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
    case askUserQuestion(AskUserQuestionToolData)
    case exitPlanMode(ExitPlanModeToolData)
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
        case .askUserQuestion(let d): return d.questions.first?.question ?? "Question"
        case .exitPlanMode: return "Plan ready for review"
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

    /// Whether this tool needs an interactive prompt (permission or question).
    public var needsPrompt: Bool {
        switch self {
        case .bash, .edit, .write, .askUserQuestion, .exitPlanMode: return true
        default: return false
        }
    }
}

// MARK: - Tool Response (from toolUseResult)

/// Represents the user's response to an interactive prompt, extracted from `toolUseResult`.
public enum ToolResponse {
    /// User answered questions: maps question text → selected answer
    case answered([String: String])
    /// User approved (e.g. ExitPlanMode)
    case approved
    /// User rejected/clarified with feedback
    case rejected(feedback: String)
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
    /// tool_use_ids that have been resolved via tool_result (user messages only).
    public let toolResultIDs: Set<String>
    /// User's structured responses to interactive prompts, keyed by tool_use_id.
    public let toolResponses: [String: ToolResponse]

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
        /// Track tool_use IDs that need prompts (permissions, questions) for response display
        var promptToolIDs: Set<String> = []

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
                        timestamp: ts, thinking: nil, textContent: [text], toolCalls: [],
                        toolResultIDs: [], toolResponses: [:]
                    ))
                }
                continue
            }

            if type == "user" {
                var texts: [String] = []
                var resultIDs: Set<String> = []
                var responses: [String: ToolResponse] = [:]

                // Extract toolUseResult from top-level entry (structured response data)
                let toolUseResult = raw["toolUseResult"]

                for item in contentArr {
                    let itemType = item["type"] as? String ?? ""
                    if itemType == "text", let t = item["text"] as? String, !t.isEmpty {
                        texts.append(t)
                    } else if itemType == "tool_result", let tid = item["tool_use_id"] as? String {
                        resultIDs.insert(tid)
                        let isError = item["is_error"] as? Bool ?? false

                        if isError {
                            // Rejected — extract user feedback from toolUseResult string
                            if let tur = toolUseResult as? String,
                               let range = tur.range(of: "the user said:\n") {
                                let feedback = String(tur[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                                responses[tid] = .rejected(feedback: feedback)
                                texts.append(feedback)
                            } else {
                                responses[tid] = .rejected(feedback: "")
                            }
                        } else if let tur = toolUseResult as? [String: Any],
                                  let answers = tur["answers"] as? [String: String] {
                            // AskUserQuestion — structured answers
                            responses[tid] = .answered(answers)
                            let answerText = answers.values.joined(separator: ", ")
                            texts.append(answerText)
                        } else if let tur = toolUseResult as? [String: Any],
                                  tur["plan"] != nil {
                            // ExitPlanMode approved
                            responses[tid] = .approved
                            texts.append("Plan approved")
                        } else if promptToolIDs.contains(tid) {
                            // Permission tool allowed (Bash/Edit/Write)
                            responses[tid] = .approved
                            texts.append("Allowed")
                        }
                    }
                }

                guard !texts.isEmpty || !resultIDs.isEmpty else { continue }
                result.append(LogMessage(
                    id: "user-\(result.count)", role: .user, model: nil,
                    timestamp: ts, thinking: nil, textContent: texts, toolCalls: [],
                    toolResultIDs: resultIDs, toolResponses: responses
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
                            if toolData.needsPrompt {
                                promptToolIDs.insert(toolId)
                            }
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
                    textContent: texts, toolCalls: tools,
                    toolResultIDs: [], toolResponses: [:]
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
                        toolCalls: mergedTools,
                        toolResultIDs: [], toolResponses: [:]
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
    /// When sessionID is empty (newly spawned), finds the most recent JSONL in the project directory.
    public static func resolveURL(agent: AgentInfo, target: LogTarget) -> URL {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let encoded = SessionScanner.encodeProjectPath(agent.workingDir)
        let projectDir = projectsDir.appendingPathComponent(encoded)

        switch target {
        case .parent:
            return projectDir.appendingPathComponent("\(agent.sessionID).jsonl")
        case .subagent(let sub):
            return projectDir
                .appendingPathComponent(agent.sessionID)
                .appendingPathComponent("subagents")
                .appendingPathComponent("\(sub.agentID).jsonl")
        }
    }

    /// Find which .jsonl file a specific PID has open via lsof.
    private static func jsonlForPID(_ pid: Int) -> String? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-a", "-p", "\(pid)", "-Fn"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            for line in output.split(separator: "\n") {
                if line.hasPrefix("n"), line.hasSuffix(".jsonl"), !line.contains("/subagents/") {
                    return String(line.dropFirst())
                }
            }
        } catch {}
        return nil
    }

    /// Find the most recently modified .jsonl file in a directory.
    private static func mostRecentJSONL(in dir: URL) -> URL? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        return files
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { url -> (URL, Date)? in
                let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return (url, mtime)
            }
            .max(by: { $0.1 < $1.1 })?
            .0
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
        case "AskUserQuestion":
            var questions: [AskUserQuestionToolData.Question] = []
            if let qArr = input["questions"] as? [[String: Any]] {
                for q in qArr {
                    var options: [AskUserQuestionToolData.Option] = []
                    if let opts = q["options"] as? [[String: Any]] {
                        for o in opts {
                            options.append(AskUserQuestionToolData.Option(
                                label: o["label"] as? String ?? "",
                                description: o["description"] as? String ?? ""
                            ))
                        }
                    }
                    questions.append(AskUserQuestionToolData.Question(
                        question: q["question"] as? String ?? "",
                        header: q["header"] as? String ?? "",
                        options: options,
                        multiSelect: q["multiSelect"] as? Bool ?? false
                    ))
                }
            }
            return .askUserQuestion(AskUserQuestionToolData(questions: questions))
        case "ExitPlanMode":
            return .exitPlanMode(ExitPlanModeToolData(plan: str("plan")))
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
