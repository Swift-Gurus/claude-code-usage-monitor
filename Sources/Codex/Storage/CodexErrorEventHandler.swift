import Foundation

/**
 solid-name: CodexErrorEventHandler
 solid-category: service
 solid-description: Converts Codex error events into retained system messages.
 */
struct CodexErrorEventHandler: CodexEventHandling {
    private let contentNormalizer: CodexEventContentNormalizing

    init(contentNormalizer: CodexEventContentNormalizing = CodexEventContentNormalizer()) {
        self.contentNormalizer = contentNormalizer
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        guard let text = contentNormalizer.errorText(from: rollout.payload) else { return }
        state.messages.appendMessage(LogMessage(
            id: "codex-error-\(rollout.offset)",
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
