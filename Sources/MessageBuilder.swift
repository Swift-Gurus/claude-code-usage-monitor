/**
 solid-name: MessageBuilding
 solid-category: abstraction
 solid-description: Contract for adding assistant messages with automatic deduplication of streamed partials.
 */
protocol MessageBuilding {
    mutating func addAssistantMessage(
        _ message: LogMessage, into result: inout [LogMessage], assistantIdxByToolUseID: inout ToolUseIndexing
    )
}

/**
 solid-name: MessageBuilder
 solid-category: service
 solid-description: Service that consolidates streamed assistant message partials into single messages.
 */
struct MessageBuilder: MessageBuilding {
    private var assistantByID: [String: (index: Int, msg: LogMessage)] = [:]

    mutating func addAssistantMessage(
        _ logMsg: LogMessage, into result: inout [LogMessage], assistantIdxByToolUseID: inout ToolUseIndexing
    ) {
        let msgID = logMsg.id

        guard let existing = assistantByID[msgID] else {
            let idx = result.count
            assistantByID[msgID] = (idx, logMsg)
            result.append(logMsg)
            for tc in logMsg.toolCalls {
                assistantIdxByToolUseID.record(messageIdx: idx, forToolUseID: tc.id)
            }
            return
        }

        let prev = existing.msg
        var mergedTools = prev.toolCalls
        let existingIds = Set(mergedTools.map(\.id))
        for tc in logMsg.toolCalls where !existingIds.contains(tc.id) {
            mergedTools.append(tc)
        }
        var merged = LogMessage(
            id: msgID, role: .assistant,
            model: logMsg.model ?? prev.model,
            timestamp: logMsg.timestamp ?? prev.timestamp,
            thinking: logMsg.thinking ?? prev.thinking,
            textContent: logMsg.textContent.isEmpty ? prev.textContent : logMsg.textContent,
            toolCalls: mergedTools,
            toolResultIDs: [], toolResponses: [:],
            toolResultContents: [:]
        )
        merged.usage = logMsg.usage ?? prev.usage
        result[existing.index] = merged
        assistantByID[msgID] = (existing.index, merged)
        for tc in logMsg.toolCalls where !existingIds.contains(tc.id) {
            assistantIdxByToolUseID.record(messageIdx: existing.index, forToolUseID: tc.id)
        }
    }
}
