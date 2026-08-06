import Foundation

/**
 solid-name: CodexReasoningResponseHandler
 solid-category: service
 solid-description: Retains canonical Codex reasoning summaries when nearby reasoning does not already represent them.
 */
struct CodexReasoningResponseHandler: CodexResponseItemHandling {
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
        let summary = (rollout.payload.summary ?? [])
            .compactMap(\.text)
            .compactMap(textNormalizer.normalize)
            .joined(separator: "\n")
        guard !summary.isEmpty else { return }
        guard !duplicateChecker.isDuplicate(
            text: summary,
            timestamp: rollout.timestamp,
            messages: state.messages.parsedMessages
        ) else { return }

        state.messages.appendMessage(LogMessage(
            id: "codex-reasoning-\(rollout.offset)",
            role: .assistant,
            model: nil,
            timestamp: rollout.timestamp,
            thinking: summary,
            textContent: [],
            toolCalls: [],
            toolResultIDs: [],
            toolResponses: [:],
            toolResultContents: [:]
        ))
    }
}
