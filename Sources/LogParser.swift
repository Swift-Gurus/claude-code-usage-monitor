import Foundation

/**
 solid-name: LogParser
 solid-category: utility
 solid-description: Parses a JSONL conversation file into display-ready log messages, deduplicating assistant messages by ID.
 */
struct LogParser: LogMessageParsing {
    private let lineReader: JSONLRawLineReading
    private let hookLineHandler: HookLineHandling
    private let userMessageBuilder: UserMessageBuilding
    private let assistantMessageParser: AssistantMessageParsing
    private let messageBuilder: MessageBuilding

    init(
        lineReader: JSONLRawLineReading = JSONLRawLineReader(),
        hookLineHandler: HookLineHandling = HookLineHandler(),
        userMessageBuilder: UserMessageBuilding = UserMessageBuilder(),
        assistantMessageParser: AssistantMessageParsing = AssistantMessageParser(),
        messageBuilder: MessageBuilding = MessageBuilder()
    ) {
        self.lineReader = lineReader
        self.hookLineHandler = hookLineHandler
        self.userMessageBuilder = userMessageBuilder
        self.assistantMessageParser = assistantMessageParser
        self.messageBuilder = messageBuilder
    }

    /// Parse a JSONL file into display-ready messages.
    /// Deduplicates assistant messages by message.id (last entry wins).
    /// User messages are kept in order.
    func parseMessages(at url: URL) -> [LogMessage] {
        var result: [LogMessage] = []
        var assistantIdxByToolUseID: ToolUseIndexing = ToolUseIndex()
        var hookLineHandler = hookLineHandler
        var assistantMessageParser = assistantMessageParser
        var messageBuilder = messageBuilder

        for raw in lineReader.readLines(at: url) {
            let type = raw["type"] as? String ?? ""
            let ts = (raw["timestamp"] as? String).flatMap { Self.timestampFormatter.date(from: $0) }

            if hookLineHandler.handle(type: type, raw: raw, timestamp: ts, result: &result, assistantIdxByToolUseID: assistantIdxByToolUseID) {
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
                if let userMsg = userMessageBuilder.build(
                    contentArr: contentArr, toolUseResult: raw["toolUseResult"], timestamp: ts,
                    messageIndex: result.count, promptToolIDs: assistantMessageParser.promptToolIDs
                ) {
                    result.append(userMsg)
                }
            } else if type == "assistant" {
                let msgID = msg["id"] as? String ?? "assistant-\(result.count)"
                if let logMsg = assistantMessageParser.parse(
                    model: msg["model"] as? String, contentArr: contentArr, timestamp: ts,
                    rawUsage: msg["usage"] as? [String: Any], messageID: msgID
                ) {
                    messageBuilder.addAssistantMessage(logMsg, into: &result, assistantIdxByToolUseID: &assistantIdxByToolUseID)
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
