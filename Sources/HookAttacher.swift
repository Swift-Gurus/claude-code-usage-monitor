import Foundation

/**
 solid-name: HookAttaching
 solid-category: abstraction
 solid-description: Contract for attaching hook tool calls to messages and locating them.
 */
protocol HookAttaching {
    mutating func attach(
        _ hookCall: LogToolCall, toolUseID: String, timestamp: Date?,
        into result: inout [LogMessage], assistantIdxByToolUseID: ToolUseIndexing
    )
    func existingRef(for toolUseID: String) -> (messageIdx: Int, toolCallIdx: Int)?
    func appendingToolCall(_ toolCall: LogToolCall, to message: LogMessage) -> LogMessage
}

/**
 solid-name: HookAttacher
 solid-category: service
 solid-description: Service for attaching hook tool calls to messages and locating them.
 */
struct HookAttacher: HookAttaching {
    private var refManager: HookReferenceTracking
    private let messageFactory: MessageFactory

    init(refManager: HookReferenceTracking = HookReferenceManager(), messageFactory: MessageFactory = DefaultMessageFactory()) {
        self.refManager = refManager
        self.messageFactory = messageFactory
    }

    mutating func attach(
        _ hookCall: LogToolCall, toolUseID: String, timestamp: Date?,
        into result: inout [LogMessage], assistantIdxByToolUseID: ToolUseIndexing
    ) {
        let idx: Int
        if let assistantIdx = assistantIdxByToolUseID.messageIndex(forToolUseID: toolUseID) {
            result[assistantIdx] = messageFactory.appendingToolCall(hookCall, to: result[assistantIdx])
            idx = assistantIdx
        } else {
            result.append(messageFactory.makeSystemMessage(id: "system-\(result.count)", timestamp: timestamp, toolCalls: [hookCall]))
            idx = result.count - 1
        }
        refManager.setRef((idx, result[idx].toolCalls.count - 1), for: toolUseID)
    }

    func existingRef(for toolUseID: String) -> (messageIdx: Int, toolCallIdx: Int)? {
        refManager.ref(for: toolUseID)
    }

    func appendingToolCall(_ toolCall: LogToolCall, to message: LogMessage) -> LogMessage {
        messageFactory.appendingToolCall(toolCall, to: message)
    }
}
