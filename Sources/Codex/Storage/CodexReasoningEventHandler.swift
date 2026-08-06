import Foundation

/**
 solid-name: CodexReasoningEventHandler
 solid-category: service
 solid-description: Retains Codex reasoning events with visible context while suppressing exact nearby repeats.
 */
struct CodexReasoningEventHandler: CodexEventHandling {
    private let textNormalizer: OptionalTextNormalizing
    private let duplicateChecker: CodexReasoningDuplicateChecking

    init(
        textNormalizer: OptionalTextNormalizing = WhitespaceTextNormalizer(),
        duplicateChecker: CodexReasoningDuplicateChecking = CodexReasoningDuplicateChecker()
    ) {
        self.textNormalizer = textNormalizer
        self.duplicateChecker = duplicateChecker
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        guard let text = textNormalizer.normalize(rollout.payload.text) else { return }
        guard !duplicateChecker.isDuplicate(
            text: text,
            timestamp: rollout.timestamp,
            messages: state.messages.parsedMessages
        ) else { return }

        state.messages.appendMessage(LogMessage(
            id: "codex-reasoning-event-\(rollout.offset)",
            role: .assistant,
            model: nil,
            timestamp: rollout.timestamp,
            thinking: text,
            textContent: [],
            toolCalls: [],
            toolResultIDs: [],
            toolResponses: [:],
            toolResultContents: [:]
        ))
    }
}
