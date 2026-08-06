import Foundation

/**
 solid-name: CodexToolCallParsing
 solid-category: abstraction
 solid-description: Contract for translating a Codex tool invocation into displayable tool calls.
 */
protocol CodexToolCallParsing {
    func toolCalls(
        for payload: CodexRolloutPayload,
        callID: String,
        input: [String: Any]
    ) -> [LogToolCall]
}
