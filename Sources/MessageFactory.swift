import Foundation

/**
 solid-name: MessageFactory
 solid-category: abstraction
 solid-description: Contract for creating and modifying log messages.
 */
protocol MessageFactory {
    func makeSystemMessage(id: String, timestamp: Date?, toolCalls: [LogToolCall]) -> LogMessage
    func appendingToolCall(_ toolCall: LogToolCall, to message: LogMessage) -> LogMessage
}

/**
 solid-name: DefaultMessageFactory
 solid-category: service
 solid-description: Default implementation for creating and modifying log messages.
 */
struct DefaultMessageFactory: MessageFactory {
    func makeSystemMessage(id: String, timestamp: Date?, toolCalls: [LogToolCall]) -> LogMessage {
        LogMessage(
            id: id, role: .system, model: nil,
            timestamp: timestamp, thinking: nil, textContent: [], toolCalls: toolCalls,
            toolResultIDs: [], toolResponses: [:], toolResultContents: [:]
        )
    }

    func appendingToolCall(_ toolCall: LogToolCall, to message: LogMessage) -> LogMessage {
        var tools = message.toolCalls
        tools.append(toolCall)
        var copy = LogMessage(
            id: message.id, role: message.role, model: message.model,
            timestamp: message.timestamp, thinking: message.thinking,
            textContent: message.textContent, toolCalls: tools,
            toolResultIDs: message.toolResultIDs,
            toolResponses: message.toolResponses,
            toolResultContents: message.toolResultContents
        )
        copy.usage = message.usage
        return copy
    }
}
