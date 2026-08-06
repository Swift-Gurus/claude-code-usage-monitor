import Foundation

/**
 solid-name: CodexGenericEventHandler
 solid-category: service
 solid-description: Converts displayable Codex events into retained system messages.
 */
struct CodexGenericEventHandler: CodexEventHandling {
    private let contentNormalizer: CodexEventContentNormalizing

    init(contentNormalizer: CodexEventContentNormalizing = CodexEventContentNormalizer()) {
        self.contentNormalizer = contentNormalizer
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        guard let text = contentNormalizer.genericEventText(from: rollout.payload) else { return }
        state.messages.appendMessage(LogMessage(
            id: "codex-event-\(rollout.offset)",
            role: .system,
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
