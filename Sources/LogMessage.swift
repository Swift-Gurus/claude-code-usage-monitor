import Foundation

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
    public let id = UUID()
    public let name: String
    public let summary: String
    public let detail: String  // full input content for expand
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

        let decoder = JSONDecoder()
        var result: [LogMessage] = []
        // Track assistant messages by id for dedup (last wins)
        var assistantByID: [String: (index: Int, msg: LogMessage)] = [:]

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let entry = try? decoder.decode(LogEntry.self, from: lineData)
            else { continue }

            let ts = entry.parsedTimestamp

            if entry.type == "user" {
                let texts = entry.message?.textBlocks ?? []
                guard !texts.isEmpty else { continue }
                let msg = LogMessage(
                    id: "user-\(result.count)",
                    role: .user,
                    model: nil,
                    timestamp: ts,
                    thinking: nil,
                    textContent: texts,
                    toolCalls: []
                )
                result.append(msg)
            } else if entry.type == "assistant", let message = entry.message {
                let texts = message.textBlocks
                let thinking = message.thinkingBlocks.joined(separator: "\n\n")
                let tools = (message.toolCalls ?? []).map { tc in
                    LogToolCall(name: tc.name, summary: toolSummary(tc), detail: toolDetail(tc))
                }
                guard !texts.isEmpty || !tools.isEmpty || !thinking.isEmpty else { continue }

                let msgID = message.id ?? "assistant-\(result.count)"
                let msg = LogMessage(
                    id: msgID,
                    role: .assistant,
                    model: message.model,
                    timestamp: ts,
                    thinking: thinking.isEmpty ? nil : thinking,
                    textContent: texts,
                    toolCalls: tools
                )

                if let existing = assistantByID[msgID] {
                    // Merge: keep the richest version of each field
                    let prev = existing.msg
                    let merged = LogMessage(
                        id: msgID,
                        role: .assistant,
                        model: msg.model ?? prev.model,
                        timestamp: msg.timestamp ?? prev.timestamp,
                        thinking: msg.thinking ?? prev.thinking,
                        textContent: msg.textContent.isEmpty ? prev.textContent : msg.textContent,
                        toolCalls: msg.toolCalls.isEmpty ? prev.toolCalls : msg.toolCalls
                    )
                    result[existing.index] = merged
                    assistantByID[msgID] = (existing.index, merged)
                } else {
                    assistantByID[msgID] = (result.count, msg)
                    result.append(msg)
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

    // MARK: - Private

    private static func toolSummary(_ tc: LogEntry.ToolCall) -> String {
        let input = tc.input
        if let fp = input.file_path { return fp }
        if let cmd = input.command {
            let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(80))
        }
        if let pattern = input.pattern { return pattern }
        if let query = input.query { return query }
        if let url = input.url { return url }
        if let prompt = input.prompt { return String(prompt.prefix(80)) }
        if let content = input.content { return String(content.prefix(60)) + (content.count > 60 ? "..." : "") }
        return ""
    }

    private static func toolDetail(_ tc: LogEntry.ToolCall) -> String {
        let input = tc.input
        var parts: [String] = []

        if let fp = input.file_path { parts.append(fp) }

        switch tc.name {
        case "Bash":
            if let cmd = input.command { parts.append(cmd) }
        case "Edit":
            if let old = input.old_string, !old.isEmpty {
                parts.append("--- old ---\n\(old)")
            }
            if let new = input.new_string, !new.isEmpty {
                parts.append("+++ new +++\n\(new)")
            }
        case "Write":
            if let content = input.content { parts.append(content) }
        case "Grep":
            if let pattern = input.pattern { parts.append("pattern: \(pattern)") }
        case "Glob":
            if let pattern = input.pattern { parts.append("pattern: \(pattern)") }
        case "Read":
            break // file_path is enough
        case "WebFetch":
            if let url = input.url { parts.append(url) }
            if let prompt = input.prompt { parts.append(prompt) }
        case "WebSearch":
            if let query = input.query { parts.append(query) }
        default:
            if let prompt = input.prompt { parts.append(prompt) }
            if let content = input.content { parts.append(content) }
            if let cmd = input.command { parts.append(cmd) }
        }

        return parts.joined(separator: "\n")
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - JSONL Types (self-contained, focused on message display)

    private struct LogEntry: Decodable {
        let type: String
        let message: MessageContent?
        let timestamp: String?

        var parsedTimestamp: Date? {
            guard let ts = timestamp else { return nil }
            return LogParser.timestampFormatter.date(from: ts)
        }

        struct MessageContent: Decodable {
            let id: String?
            let model: String?
            let content: [ContentItem]?

            var toolCalls: [ToolCall]? {
                content?.compactMap {
                    if case .toolCall(let t) = $0 { return t }
                    return nil
                }
            }

            var textBlocks: [String] {
                content?.compactMap {
                    if case .text(let t) = $0, !t.isEmpty { return t }
                    return nil
                } ?? []
            }

            var thinkingBlocks: [String] {
                content?.compactMap {
                    if case .thinking(let t) = $0, !t.isEmpty { return t }
                    return nil
                } ?? []
            }

            enum ContentItem: Decodable {
                case toolCall(ToolCall)
                case text(String)
                case thinking(String)
                case other

                init(from decoder: Decoder) throws {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    let type = try? c.decode(String.self, forKey: .type)
                    if type == "tool_use" {
                        self = .toolCall(try ToolCall(from: decoder))
                    } else if type == "text" {
                        let text = (try? c.decode(String.self, forKey: .text)) ?? ""
                        self = .text(text)
                    } else if type == "thinking" {
                        let thinking = (try? c.decode(String.self, forKey: .thinking)) ?? ""
                        self = .thinking(thinking)
                    } else {
                        self = .other
                    }
                }

                enum CodingKeys: String, CodingKey { case type, text, thinking }
            }
        }

        struct ToolCall: Decodable {
            let name: String
            let input: ToolInput

            struct ToolInput: Decodable {
                let file_path: String?
                let command: String?
                let pattern: String?
                let query: String?
                let url: String?
                let prompt: String?
                let content: String?
                let old_string: String?
                let new_string: String?
            }
        }
    }
}
