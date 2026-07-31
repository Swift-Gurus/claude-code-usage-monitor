import Foundation

/**
 solid-name: AssistantMessageParsing
 solid-category: abstraction
 solid-description: Contract for parsing assistant messages and identifying tool calls that require user responses.
 */
protocol AssistantMessageParsing {
    var promptToolIDs: Set<String> { get }
    mutating func parse(
        model: String?, contentArr: [[String: Any]], timestamp: Date?,
        rawUsage: [String: Any]?, messageID: String
    ) -> LogMessage?
}

/**
 solid-name: AssistantMessageParser
 solid-category: service
 solid-description: Parses assistant message content, extracts token usage information, and identifies tool calls that require user responses.
 */
struct AssistantMessageParser: AssistantMessageParsing {
    private let toolDataParser: ToolDataParsing
    private(set) var promptToolIDs: Set<String> = []

    init(toolDataParser: ToolDataParsing = ToolDataParser()) {
        self.toolDataParser = toolDataParser
    }

    mutating func parse(
        model: String?, contentArr: [[String: Any]], timestamp: Date?,
        rawUsage: [String: Any]?, messageID: String
    ) -> LogMessage? {
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

        guard !texts.isEmpty || !tools.isEmpty || !thinkingParts.isEmpty else { return nil }

        let thinking = thinkingParts.isEmpty ? nil : thinkingParts.joined(separator: "\n\n")
        var logMsg = LogMessage(
            id: messageID, role: .assistant, model: model,
            timestamp: timestamp, thinking: thinking,
            textContent: texts, toolCalls: tools,
            toolResultIDs: [], toolResponses: [:], toolResultContents: [:]
        )
        logMsg.usage = parseUsage(rawUsage)
        return logMsg
    }

    /// Same field names as JSONLParser's private `Usage` type.
    private func parseUsage(_ raw: [String: Any]?) -> TokenUsage? {
        guard let raw else { return nil }
        return TokenUsage(
            inputTokens: raw["input_tokens"] as? Int ?? 0,
            outputTokens: raw["output_tokens"] as? Int ?? 0,
            cacheCreationTokens: raw["cache_creation_input_tokens"] as? Int ?? 0,
            cacheReadTokens: raw["cache_read_input_tokens"] as? Int ?? 0
        )
    }
}
