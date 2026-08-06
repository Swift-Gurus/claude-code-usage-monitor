import Foundation

/**
 solid-name: CodexTokenEventHandler
 solid-category: service
 solid-description: Applies Codex token-count events to cumulative usage state and retained messages.
 */
struct CodexTokenEventHandler: CodexEventHandling {
    private let messageBuilder: CodexTokenUsageMessageBuilding

    init(messageBuilder: CodexTokenUsageMessageBuilding = CodexTokenUsageMessageBuilder()) {
        self.messageBuilder = messageBuilder
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        var cumulativeUsage = state.tokens.cumulativeTokenUsage
        let message = messageBuilder.message(
            for: rollout.payload,
            offset: rollout.offset,
            timestamp: rollout.timestamp,
            cumulativeUsage: &cumulativeUsage
        )
        state.tokens.cumulativeTokenUsage = cumulativeUsage
        if let message {
            state.messages.appendMessage(message)
        }
    }
}
