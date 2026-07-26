import Foundation

struct CodexMessageContent: Decodable {
    let type: String
    let text: String?
}

/**
 solid-name: CodexLogParser
 solid-category: service
 solid-description: Parses Codex rollout JSONL files into the shared LogMessage model so the existing log viewer can render Codex sessions with the same expandable request/result chips used for Claude logs.
 */
struct CodexLogParser: LogMessageParsing {
    private let lineDecoder: CodexJSONLDecoding
    private let dateParser: CodexDateParser
    private let toolDataParser: ToolDataParsing

    init(
        lineDecoder: CodexJSONLDecoding = CodexJSONLFileDecoder(),
        dateParser: CodexDateParser = CodexDateParser(),
        toolDataParser: ToolDataParsing = ToolDataParser()
    ) {
        self.lineDecoder = lineDecoder
        self.dateParser = dateParser
        self.toolDataParser = toolDataParser
    }

    func parseMessages(at url: URL) -> [LogMessage] {
        let lines = lineDecoder.decodeLines(at: url, as: CodexRolloutLine.self)
        var result: [LogMessage] = []
        var messageIndexByCallID: [String: Int] = [:]

        for (offset, line) in lines.enumerated() {
            let timestamp = line.timestamp.flatMap(dateParser.parse)
            guard let payload = line.payload else { continue }

            switch line.type {
            case "response_item":
                switch payload.type {
                case "message":
                    let role = role(for: payload.role)
                    let textContent = (payload.content ?? [])
                        .compactMap(\.text)
                        .filter { !$0.isEmpty }
                    guard !textContent.isEmpty else { continue }
                    result.append(LogMessage(
                        id: "codex-message-\(offset)",
                        role: role,
                        model: nil,
                        timestamp: timestamp,
                        thinking: nil,
                        textContent: textContent,
                        toolCalls: [],
                        toolResultIDs: [],
                        toolResponses: [:],
                        toolResultContents: [:]
                    ))
                case "function_call", "custom_tool_call":
                    let input = parsedInput(for: payload)
                    let callID = payload.callID ?? "codex-call-\(offset)"
                    let toolCall = LogToolCall(
                        id: callID,
                        name: payload.name ?? "Tool",
                        data: toolDataParser.parseToolData(name: payload.name ?? "Tool", input: input)
                    )
                    let message = LogMessage(
                        id: "codex-call-message-\(callID)",
                        role: .assistant,
                        model: nil,
                        timestamp: timestamp,
                        thinking: nil,
                        textContent: [],
                        toolCalls: [toolCall],
                        toolResultIDs: [],
                        toolResponses: [:],
                        toolResultContents: [:]
                    )
                    messageIndexByCallID[callID] = result.count
                    result.append(message)
                case "function_call_output", "custom_tool_call_output":
                    attachResult(
                        normalizedResultContent(from: payload.output),
                        to: payload.callID,
                        in: &result,
                        messageIndexByCallID: messageIndexByCallID
                    )
                default:
                    continue
                }
            case "event_msg":
                switch payload.type {
                case "user_message":
                    guard let text = normalizedText(payload.message), !text.isEmpty else { continue }
                    result.append(LogMessage(
                        id: "codex-user-\(offset)",
                        role: .user,
                        model: nil,
                        timestamp: timestamp,
                        thinking: nil,
                        textContent: [text],
                        toolCalls: [],
                        toolResultIDs: [],
                        toolResponses: [:],
                        toolResultContents: [:]
                    ))
                case "error":
                    guard let text = normalizedErrorText(from: payload), !text.isEmpty else { continue }
                    result.append(LogMessage(
                        id: "codex-error-\(offset)",
                        role: .system,
                        model: nil,
                        timestamp: timestamp,
                        thinking: nil,
                        textContent: [text],
                        toolCalls: [],
                        toolResultIDs: [],
                        toolResponses: [:],
                        toolResultContents: [:]
                    ))
                case "exec_command_end", "patch_apply_end":
                    attachResult(
                        eventResultContent(from: payload),
                        to: payload.callID,
                        in: &result,
                        messageIndexByCallID: messageIndexByCallID
                    )
                default:
                    guard let text = genericEventText(for: payload) else { continue }
                    result.append(LogMessage(
                        id: "codex-event-\(offset)",
                        role: .system,
                        model: nil,
                        timestamp: timestamp,
                        thinking: nil,
                        textContent: [text],
                        toolCalls: [],
                        toolResultIDs: [],
                        toolResponses: [:],
                        toolResultContents: [:]
                    ))
                }
            default:
                continue
            }
        }

        return result
    }

    private func role(for rawRole: String?) -> LogMessage.Role {
        switch rawRole {
        case "assistant": return .assistant
        case "developer": return .system
        default: return .user
        }
    }

    private func parsedInput(for payload: CodexRolloutPayload) -> [String: Any] {
        if let json = decodeJSONObject(payload.arguments) {
            return json
        }
        if let rawInput = normalizedText(payload.input), !rawInput.isEmpty {
            return ["input": rawInput]
        }
        return [:]
    }

    private func decodeJSONObject(_ raw: String?) -> [String: Any]? {
        guard let raw,
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private func attachResult(
        _ resultContent: String?,
        to callID: String?,
        in result: inout [LogMessage],
        messageIndexByCallID: [String: Int]
    ) {
        guard let callID,
              let resultContent,
              !resultContent.isEmpty,
              let index = messageIndexByCallID[callID],
              index < result.count
        else { return }

        let previous = result[index]
        var toolResultContents = previous.toolResultContents
        if let existing = toolResultContents[callID], !existing.isEmpty, existing == resultContent {
            return
        }
        toolResultContents[callID] = resultContent
        result[index] = LogMessage(
            id: previous.id,
            role: previous.role,
            model: previous.model,
            timestamp: previous.timestamp,
            thinking: previous.thinking,
            textContent: previous.textContent,
            toolCalls: previous.toolCalls,
            toolResultIDs: previous.toolResultIDs,
            toolResponses: previous.toolResponses,
            toolResultContents: toolResultContents
        )
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedResultContent(from raw: String?) -> String? {
        guard let raw = normalizedText(raw) else { return nil }
        guard let object = decodeJSONObject(raw) else { return raw }

        if let output = normalizedText(object["output"] as? String) {
            return output
        }

        if let metadata = object["metadata"] as? [String: Any], !metadata.isEmpty {
            let metadataText = metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            if let output = object["output"] as? String, !output.isEmpty {
                return output + "\n\n" + metadataText
            }
            return metadataText
        }

        return raw
    }

    private func eventResultContent(from payload: CodexRolloutPayload) -> String? {
        var parts: [String] = []
        if let aggregated = normalizedText(payload.aggregatedOutput) {
            parts.append(aggregated)
        } else if let stdout = normalizedText(payload.stdout) {
            parts.append(stdout)
        }
        if let stderr = normalizedText(payload.stderr) {
            parts.append(stderr)
        }
        if let success = payload.success {
            parts.append(success ? "status: completed" : "status: failed")
        }
        let joined = parts.joined(separator: "\n\n")
        return joined.isEmpty ? nil : joined
    }

    private func normalizedErrorText(from payload: CodexRolloutPayload) -> String? {
        normalizedText(payload.message)
    }

    private func genericEventText(for payload: CodexRolloutPayload) -> String? {
        guard let eventType = payload.type, !ignoredEventTypes.contains(eventType) else { return nil }

        var parts: [String] = []
        if let message = normalizedText(payload.message) {
            parts.append(message)
        }
        if let output = normalizedText(payload.output) {
            parts.append(output)
        }
        if let aggregatedOutput = normalizedText(payload.aggregatedOutput) {
            parts.append(aggregatedOutput)
        }
        if let stdout = normalizedText(payload.stdout) {
            parts.append(stdout)
        }
        if let stderr = normalizedText(payload.stderr) {
            parts.append(stderr)
        }

        if parts.isEmpty {
            return eventType
        }
        return eventType + "\n" + parts.joined(separator: "\n\n")
    }

    private var ignoredEventTypes: Set<String> {
        [
            "agent_message",
            "exec_command_end",
            "patch_apply_end",
            "task_complete",
            "task_started",
            "thread_name_updated",
            "token_count",
            "user_message"
        ]
    }
}
