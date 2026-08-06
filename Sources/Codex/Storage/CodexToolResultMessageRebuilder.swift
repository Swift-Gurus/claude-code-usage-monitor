import Foundation

/**
 solid-name: CodexToolResultMessageRebuilder
 solid-category: service
 solid-description: Rebuilds parsed messages with Codex tool-result content.
 */
struct CodexToolResultMessageRebuilder: CodexToolResultMessageRebuilding {
    func replacingToolResult(
        in message: LogMessage,
        callID: String,
        content: String
    ) -> LogMessage {
        var resultContents = message.toolResultContents
        resultContents[callID] = content
        return LogMessage(
            id: message.id,
            role: message.role,
            model: message.model,
            timestamp: message.timestamp,
            thinking: message.thinking,
            textContent: message.textContent,
            toolCalls: message.toolCalls,
            toolResultIDs: message.toolResultIDs,
            toolResponses: message.toolResponses,
            toolResultContents: resultContents
        )
    }
}
