import Foundation

/**
 solid-name: CodexUserEventHandler
 solid-category: service
 solid-description: Converts Codex user events into retained log messages.
 */
struct CodexUserEventHandler: CodexEventHandling {
    private let contentNormalizer: CodexEventContentNormalizing
    private let duplicateChecker: CodexUserMessageDuplicateChecking

    init(
        contentNormalizer: CodexEventContentNormalizing = CodexEventContentNormalizer(),
        duplicateChecker: CodexUserMessageDuplicateChecking = CodexUserMessageDuplicateChecker()
    ) {
        self.contentNormalizer = contentNormalizer
        self.duplicateChecker = duplicateChecker
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        guard let text = contentNormalizer.text(rollout.payload.message) else { return }
        guard !duplicateChecker.isDuplicate(
            text: text,
            timestamp: rollout.timestamp,
            messages: state.messages.parsedMessages
        ) else { return }
        state.messages.appendMessage(LogMessage(
            id: "codex-user-\(rollout.offset)",
            role: .user,
            model: nil,
            timestamp: rollout.timestamp,
            thinking: nil,
            textContent: [text],
            toolCalls: [],
            toolResultIDs: [],
            toolResponses: [:],
            toolResultContents: [:]
        ))
    }
}
