import Foundation

/**
 solid-name: CodexToolResultAttacher
 solid-category: service
 solid-description: Attaches Codex tool-result content to parsed messages.
 */
struct CodexToolResultAttacher: CodexToolResultAttaching {
    private let messageRebuilder: CodexToolResultMessageRebuilding

    init(messageRebuilder: CodexToolResultMessageRebuilding = CodexToolResultMessageRebuilder()) {
        self.messageRebuilder = messageRebuilder
    }

    func attach(
        _ content: String?,
        callID: String?,
        messages: CodexMessageReplacing,
        toolCalls: CodexToolCallMessageLocating
    ) {
        guard let callID,
              let content,
              let index = toolCalls.messageIndex(for: callID),
              let message = messages.message(at: index),
              message.toolResultContents[callID] != content
        else { return }

        let replacement = messageRebuilder.replacingToolResult(
            in: message,
            callID: callID,
            content: content
        )
        messages.replaceMessage(replacement, at: index)
    }
}
