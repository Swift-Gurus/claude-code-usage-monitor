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
    public let offset: Int?
    public let limit: Int?

    public var lineRange: String? {
        guard let limit else { return nil }
        let start = offset ?? 0
        return "lines \(start)–\(start + limit)"
    }
}

public struct BashToolData {
    public let command: String
    public let description: String
    public let timeout: Int?
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
    public let name: String
    public let arguments: String
    public let status: String
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

public struct MCPToolData {
    public let serverName: String
    public let toolName: String
    /// String-valued input parameters (non-string values are stringified).
    public let input: [String: String]
}

public struct HookToolData {
    public enum Status {
        case progress, success, blockingError, systemMessage, cancelled
    }

    public let hookEvent: String       // "PreToolUse", "PostToolUse", "Stop", "SubagentStart", ...
    public let hookName: String        // "PostToolUse:Grep", "Stop", "SubagentStart", ...
    public let command: String         // shell command (hook_progress / stop_hook_summary)
    public let toolUseID: String
    public let durationMs: Int?
    public let errorMessage: String?
    public let context: String?        // injected content for hook_additional_context / hook_system_message
    public let stdout: String?
    public let stderr: String?
    public let exitCode: Int?
    public let status: Status?
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
    case hook(HookToolData)
    case mcp(MCPToolData)
    case other(raw: [String: String])

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
    /// Tool result text content keyed by tool_use_id (user messages only).
    public let toolResultContents: [String: String]

    public enum Role {
        case user, assistant, system
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
    case codexSession(CodexSession)

    public static func == (lhs: LogTarget, rhs: LogTarget) -> Bool {
        switch (lhs, rhs) {
        case (.parent, .parent): return true
        case (.subagent(let a), .subagent(let b)): return a.agentID == b.agentID
        case (.codexSession(let a), .codexSession(let b)): return a.threadID == b.threadID
        default: return false
        }
    }
}

/**
 solid-name: ProcessInspecting
 solid-category: abstraction
 solid-description: Contract for inspecting OS processes to find which JSONL file a given PID has open. Isolates the system-level lsof concern from JSONL parsing.
 */
protocol ProcessInspecting {
    func jsonlForPID(_ pid: Int) -> String?
}

/**
 solid-name: LsofProcessInspector
 solid-category: service
 solid-description: Boundary adapter wrapping the system-level lsof command to discover which JSONL file a specific PID has open. Encapsulates Process/Pipe usage behind the ProcessInspecting protocol.
 */
struct LsofProcessInspector: ProcessInspecting {
    func jsonlForPID(_ pid: Int) -> String? {
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
}

/**
 solid-name: SessionPathEncoding
 solid-category: abstraction
 solid-description: Contract for encoding a filesystem path into the project directory name format Claude Code uses. Replaces direct SessionScanner.encodeProjectPath calls.
 */
protocol SessionPathEncoding {
    func encodeProjectPath(_ path: String) -> String
}

/**
 solid-name: SessionPathEncoderAdapter
 solid-category: utility
 solid-description: Adapts SessionScanner's static encodeProjectPath API to the SessionPathEncoding protocol for dependency injection.
 */
struct SessionPathEncoderAdapter: SessionPathEncoding {
    func encodeProjectPath(_ path: String) -> String {
        SessionScanner.encodeProjectPath(path)
    }
}

/**
 solid-name: LogParser
 solid-category: utility
 solid-description: Parses Claude Code JSONL conversation files into display-ready LogMessage arrays. Handles deduplication of streamed assistant messages, tool call extraction, and user responses.
 */
public enum LogParser {
    private static let toolDataParser = ToolDataParser()

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
        /// Map tool_use id → result index of the assistant message that owns it (for hook attachment)
        var assistantIdxByToolUseID: [String: Int] = [:]
        /// Map toolUseID → (messageIdx, toolCallIdx) of an already-attached hook, for stop_hook_summary enrichment
        var hookRefByToolUseID: [String: (messageIdx: Int, toolCallIdx: Int)] = [:]

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }

            let type = raw["type"] as? String ?? ""
            let ts = (raw["timestamp"] as? String).flatMap { timestampFormatter.date(from: $0) }

            // Hook progress: attach as a hook tool call to the matching assistant message,
            // or emit a standalone system LogMessage for session-level hooks.
            if type == "progress",
               let data = raw["data"] as? [String: Any],
               (data["type"] as? String) == "hook_progress" {
                let hookData = HookToolData(
                    hookEvent: data["hookEvent"] as? String ?? "",
                    hookName: data["hookName"] as? String ?? "",
                    command: data["command"] as? String ?? "",
                    toolUseID: raw["toolUseID"] as? String ?? "",
                    durationMs: nil,
                    errorMessage: nil,
                    context: nil,
                    stdout: nil, stderr: nil, exitCode: nil,
                    status: .progress
                )
                let hookId = raw["uuid"] as? String ?? UUID().uuidString
                let hookCall = LogToolCall(id: "hook-\(hookId)", name: "Hook", data: .hook(hookData))

                if let assistantIdx = assistantIdxByToolUseID[hookData.toolUseID] {
                    let existing = result[assistantIdx]
                    var tools = existing.toolCalls
                    tools.append(hookCall)
                    result[assistantIdx] = LogMessage(
                        id: existing.id, role: existing.role, model: existing.model,
                        timestamp: existing.timestamp, thinking: existing.thinking,
                        textContent: existing.textContent, toolCalls: tools,
                        toolResultIDs: existing.toolResultIDs,
                        toolResponses: existing.toolResponses,
                        toolResultContents: existing.toolResultContents
                    )
                    hookRefByToolUseID[hookData.toolUseID] = (assistantIdx, tools.count - 1)
                } else {
                    let sysMsg = LogMessage(
                        id: "system-\(result.count)", role: .system, model: nil,
                        timestamp: ts, thinking: nil, textContent: [], toolCalls: [hookCall],
                        toolResultIDs: [], toolResponses: [:], toolResultContents: [:]
                    )
                    result.append(sysMsg)
                    hookRefByToolUseID[hookData.toolUseID] = (result.count - 1, 0)
                }
                continue
            }

            // stop_hook_summary: append a completion chip next to a prior hook_progress start chip,
            // or (on recent Claude Code versions where hook_progress is no longer emitted) emit a
            // standalone system message with one chip per hookInfo entry.
            if type == "system", (raw["subtype"] as? String) == "stop_hook_summary" {
                let toolUseID = raw["toolUseID"] as? String ?? ""
                let hookInfos = raw["hookInfos"] as? [[String: Any]] ?? []
                let hookErrors = raw["hookErrors"] as? [String] ?? []

                if let ref = hookRefByToolUseID[toolUseID],
                   ref.toolCallIdx < result[ref.messageIdx].toolCalls.count,
                   case .hook(let hd) = result[ref.messageIdx].toolCalls[ref.toolCallIdx].data {
                    let existing = result[ref.messageIdx]
                    let duration = hookInfos.first?["durationMs"] as? Int
                    let completion = HookToolData(
                        hookEvent: hd.hookEvent, hookName: hd.hookName,
                        command: hd.command, toolUseID: hd.toolUseID,
                        durationMs: duration, errorMessage: hookErrors.first,
                        context: hd.context,
                        stdout: hd.stdout, stderr: hd.stderr, exitCode: hd.exitCode,
                        status: hookErrors.first != nil ? .blockingError : .success
                    )
                    let completionID = "hook-\(raw["uuid"] as? String ?? UUID().uuidString)-complete"
                    var tools = existing.toolCalls
                    tools.append(LogToolCall(id: completionID, name: "Hook", data: .hook(completion)))
                    result[ref.messageIdx] = LogMessage(
                        id: existing.id, role: existing.role, model: existing.model,
                        timestamp: existing.timestamp, thinking: existing.thinking,
                        textContent: existing.textContent, toolCalls: tools,
                        toolResultIDs: existing.toolResultIDs,
                        toolResponses: existing.toolResponses,
                        toolResultContents: existing.toolResultContents
                    )
                    continue
                }

                guard !hookInfos.isEmpty else { continue }
                let baseUUID = raw["uuid"] as? String ?? UUID().uuidString
                var calls: [LogToolCall] = []
                for (i, info) in hookInfos.enumerated() {
                    let cmd = info["command"] as? String ?? ""
                    let duration = info["durationMs"] as? Int
                    let err = i < hookErrors.count ? hookErrors[i] : nil
                    let hookData = HookToolData(
                        hookEvent: "Stop", hookName: "Stop",
                        command: cmd, toolUseID: toolUseID,
                        durationMs: duration, errorMessage: err,
                        context: nil,
                        stdout: nil, stderr: nil, exitCode: nil,
                        status: err != nil ? .blockingError : .success
                    )
                    calls.append(LogToolCall(
                        id: "hook-\(baseUUID)-\(i)", name: "Hook", data: .hook(hookData)
                    ))
                }
                result.append(LogMessage(
                    id: "system-\(result.count)", role: .system, model: nil,
                    timestamp: ts, thinking: nil, textContent: [], toolCalls: calls,
                    toolResultIDs: [], toolResponses: [:], toolResultContents: [:]
                ))
                continue
            }

            // hook_additional_context: hooks that inject context (e.g. SubagentStart).
            if type == "attachment",
               let att = raw["attachment"] as? [String: Any],
               (att["type"] as? String) == "hook_additional_context" {
                let hookEvent = att["hookEvent"] as? String ?? ""
                let hookName = att["hookName"] as? String ?? hookEvent
                let toolUseID = att["toolUseID"] as? String ?? ""
                let joinedContext: String
                if let arr = att["content"] as? [String] {
                    joinedContext = arr.joined(separator: "\n")
                } else if let s = att["content"] as? String {
                    joinedContext = s
                } else {
                    joinedContext = ""
                }
                let hookData = HookToolData(
                    hookEvent: hookEvent, hookName: hookName,
                    command: "", toolUseID: toolUseID,
                    durationMs: nil, errorMessage: nil,
                    context: joinedContext.isEmpty ? nil : joinedContext,
                    stdout: nil, stderr: nil, exitCode: nil,
                    status: .systemMessage
                )
                let hookId = raw["uuid"] as? String ?? UUID().uuidString
                let hookCall = LogToolCall(id: "hook-\(hookId)", name: "Hook", data: .hook(hookData))

                if let assistantIdx = assistantIdxByToolUseID[toolUseID] {
                    let existing = result[assistantIdx]
                    var tools = existing.toolCalls
                    tools.append(hookCall)
                    result[assistantIdx] = LogMessage(
                        id: existing.id, role: existing.role, model: existing.model,
                        timestamp: existing.timestamp, thinking: existing.thinking,
                        textContent: existing.textContent, toolCalls: tools,
                        toolResultIDs: existing.toolResultIDs,
                        toolResponses: existing.toolResponses,
                        toolResultContents: existing.toolResultContents
                    )
                } else {
                    result.append(LogMessage(
                        id: "system-\(result.count)", role: .system, model: nil,
                        timestamp: ts, thinking: nil, textContent: [], toolCalls: [hookCall],
                        toolResultIDs: [], toolResponses: [:], toolResultContents: [:]
                    ))
                }
                continue
            }

            // hook_success / hook_blocking_error / hook_system_message / hook_cancelled
            // (v2.1.111+ attachment formats replacing hook_progress for PostToolUse hooks).
            if type == "attachment",
               let att = raw["attachment"] as? [String: Any],
               let attType = att["type"] as? String,
               ["hook_success", "hook_blocking_error", "hook_system_message", "hook_cancelled"].contains(attType) {
                let hookEvent = att["hookEvent"] as? String ?? ""
                let hookName = att["hookName"] as? String ?? hookEvent
                let toolUseID = att["toolUseID"] as? String ?? ""

                let status: HookToolData.Status
                let command: String
                let errorMessage: String?
                let context: String?
                let stdout: String?
                let stderr: String?
                let exitCode: Int?
                let durationMs: Int?

                switch attType {
                case "hook_success":
                    status = .success
                    command = att["command"] as? String ?? ""
                    let out = att["stdout"] as? String
                    let errOut = att["stderr"] as? String
                    stdout = (out?.isEmpty ?? true) ? nil : out
                    stderr = (errOut?.isEmpty ?? true) ? nil : errOut
                    exitCode = att["exitCode"] as? Int
                    durationMs = att["durationMs"] as? Int
                    errorMessage = nil
                    let content = att["content"] as? String
                    context = (content?.isEmpty ?? true) ? nil : content
                case "hook_blocking_error":
                    status = .blockingError
                    let be = att["blockingError"] as? [String: Any] ?? [:]
                    command = be["command"] as? String ?? att["command"] as? String ?? ""
                    errorMessage = be["blockingError"] as? String
                    stdout = nil
                    stderr = nil
                    exitCode = be["exitCode"] as? Int
                    durationMs = att["durationMs"] as? Int
                    context = nil
                case "hook_system_message":
                    status = .systemMessage
                    command = att["command"] as? String ?? ""
                    let content = att["content"] as? String
                    context = (content?.isEmpty ?? true) ? nil : content
                    stdout = nil
                    stderr = nil
                    exitCode = nil
                    durationMs = nil
                    errorMessage = nil
                case "hook_cancelled":
                    status = .cancelled
                    command = att["command"] as? String ?? ""
                    errorMessage = "Cancelled"
                    context = nil
                    stdout = nil
                    stderr = nil
                    exitCode = nil
                    durationMs = att["durationMs"] as? Int
                default:
                    continue
                }

                let hookData = HookToolData(
                    hookEvent: hookEvent, hookName: hookName,
                    command: command, toolUseID: toolUseID,
                    durationMs: durationMs, errorMessage: errorMessage,
                    context: context,
                    stdout: stdout, stderr: stderr, exitCode: exitCode,
                    status: status
                )
                let hookId = raw["uuid"] as? String ?? UUID().uuidString
                let hookCall = LogToolCall(id: "hook-\(hookId)", name: "Hook", data: .hook(hookData))

                if let assistantIdx = assistantIdxByToolUseID[toolUseID] {
                    let existing = result[assistantIdx]
                    var tools = existing.toolCalls
                    tools.append(hookCall)
                    result[assistantIdx] = LogMessage(
                        id: existing.id, role: existing.role, model: existing.model,
                        timestamp: existing.timestamp, thinking: existing.thinking,
                        textContent: existing.textContent, toolCalls: tools,
                        toolResultIDs: existing.toolResultIDs,
                        toolResponses: existing.toolResponses,
                        toolResultContents: existing.toolResultContents
                    )
                } else {
                    result.append(LogMessage(
                        id: "system-\(result.count)", role: .system, model: nil,
                        timestamp: ts, thinking: nil, textContent: [], toolCalls: [hookCall],
                        toolResultIDs: [], toolResponses: [:], toolResultContents: [:]
                    ))
                }
                continue
            }

            guard let msg = raw["message"] as? [String: Any],
                  let contentArr = msg["content"] as? [[String: Any]]
            else {
                // User text messages without content array
                if type == "user", let msgDict = raw["message"] as? [String: Any],
                   let text = msgDict["content"] as? String, !text.isEmpty {
                    result.append(LogMessage(
                        id: "user-\(result.count)", role: .user, model: nil,
                        timestamp: ts, thinking: nil, textContent: [text], toolCalls: [],
                        toolResultIDs: [], toolResponses: [:], toolResultContents: [:]
                    ))
                }
                continue
            }

            if type == "user" {
                var texts: [String] = []
                var resultIDs: Set<String> = []
                var responses: [String: ToolResponse] = [:]
                var resultContents: [String: String] = [:]

                // Extract toolUseResult from top-level entry (structured response data)
                let toolUseResult = raw["toolUseResult"]

                for item in contentArr {
                    let itemType = item["type"] as? String ?? ""
                    if itemType == "text", let t = item["text"] as? String, !t.isEmpty {
                        texts.append(t)
                    } else if itemType == "tool_result", let tid = item["tool_use_id"] as? String {
                        resultIDs.insert(tid)
                        let isError = item["is_error"] as? Bool ?? false

                        if let contentStr = item["content"] as? String, !contentStr.isEmpty {
                            resultContents[tid] = contentStr
                        } else if let contentArr = item["content"] as? [[String: Any]] {
                            let joined = contentArr.compactMap { $0["text"] as? String }.joined(separator: "\n")
                            if !joined.isEmpty { resultContents[tid] = joined }
                        }

                        if isError {
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
                            responses[tid] = .answered(answers)
                            let answerText = answers.values.joined(separator: ", ")
                            texts.append(answerText)
                        } else if let tur = toolUseResult as? [String: Any],
                                  tur["plan"] != nil {
                            responses[tid] = .approved
                            texts.append("Plan approved")
                        } else if promptToolIDs.contains(tid) {
                            responses[tid] = .approved
                            texts.append("Allowed")
                        }
                    }
                }

                guard !texts.isEmpty || !resultIDs.isEmpty else { continue }
                result.append(LogMessage(
                    id: "user-\(result.count)", role: .user, model: nil,
                    timestamp: ts, thinking: nil, textContent: texts, toolCalls: [],
                    toolResultIDs: resultIDs, toolResponses: responses,
                    toolResultContents: resultContents
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
                            let toolData = toolDataParser.parseToolData(name: name, input: input)
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
                    toolResultIDs: [], toolResponses: [:],
                    toolResultContents: [:]
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
                        toolResultIDs: [], toolResponses: [:],
                        toolResultContents: [:]
                    )
                    result[existing.index] = merged
                    assistantByID[msgID] = (existing.index, merged)
                    for tc in logMsg.toolCalls where !existingIds.contains(tc.id) {
                        assistantIdxByToolUseID[tc.id] = existing.index
                    }
                } else {
                    let idx = result.count
                    assistantByID[msgID] = (idx, logMsg)
                    result.append(logMsg)
                    for tc in logMsg.toolCalls {
                        assistantIdxByToolUseID[tc.id] = idx
                    }
                }
            }
        }

        return result
    }
    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
