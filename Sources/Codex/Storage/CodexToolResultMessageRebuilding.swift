import Foundation

/**
 solid-name: CodexToolResultMessageRebuilding
 solid-category: abstraction
 solid-description: Contract for rebuilding parsed messages with Codex tool-result content.
 */
protocol CodexToolResultMessageRebuilding {
    func replacingToolResult(
        in message: LogMessage,
        callID: String,
        content: String
    ) -> LogMessage
}
