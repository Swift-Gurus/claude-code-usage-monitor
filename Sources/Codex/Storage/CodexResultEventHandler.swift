import Foundation

/**
 solid-name: CodexResultEventHandler
 solid-category: service
 solid-description: Normalizes and attaches Codex command and patch result events.
 */
struct CodexResultEventHandler: CodexEventHandling {
    private let contentNormalizer: CodexEventContentNormalizing
    private let resultAttacher: CodexToolResultAttaching

    init(
        contentNormalizer: CodexEventContentNormalizing = CodexEventContentNormalizer(),
        resultAttacher: CodexToolResultAttaching = CodexToolResultAttacher()
    ) {
        self.contentNormalizer = contentNormalizer
        self.resultAttacher = resultAttacher
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        resultAttacher.attach(
            contentNormalizer.eventResult(from: rollout.payload),
            callID: rollout.payload.callID,
            messages: state.messages,
            toolCalls: state.toolCalls
        )
    }
}
