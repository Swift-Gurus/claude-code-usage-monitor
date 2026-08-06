import Foundation

/**
 solid-name: CodexToolResultAttaching
 solid-category: abstraction
 solid-description: Contract for attaching Codex tool-result content to parsed messages.
 */
protocol CodexToolResultAttaching {
    func attach(
        _ content: String?,
        callID: String?,
        messages: CodexMessageReplacing,
        toolCalls: CodexToolCallMessageLocating
    )
}
