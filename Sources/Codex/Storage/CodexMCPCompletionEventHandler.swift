import Foundation

/**
 solid-name: CodexMCPCompletionEventHandler
 solid-category: service
 solid-description: Retains rich MCP tool-call messages from authoritative completion events.
 */
struct CodexMCPCompletionEventHandler: CodexEventHandling {
    private let messageBuilder: CodexMCPCompletionMessageBuilding

    init(messageBuilder: CodexMCPCompletionMessageBuilding = CodexMCPCompletionMessageBuilder()) {
        self.messageBuilder = messageBuilder
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        guard let message = messageBuilder.message(from: rollout) else { return }
        state.messages.appendMessage(message)
    }
}
