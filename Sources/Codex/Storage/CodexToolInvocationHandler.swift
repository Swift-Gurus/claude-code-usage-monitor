import Foundation

/**
 solid-name: CodexToolInvocationHandler
 solid-category: service
 solid-description: Coordinates input resolution and message recording for Codex tool invocations.
 */
struct CodexToolInvocationHandler: CodexResponseItemHandling {
    private let inputResolver: CodexToolInputResolving
    private let messageRecorder: CodexToolCallMessageRecording

    init(
        inputResolver: CodexToolInputResolving = CodexToolInputResolver(),
        messageRecorder: CodexToolCallMessageRecording = CodexToolCallMessageRecorder()
    ) {
        self.inputResolver = inputResolver
        self.messageRecorder = messageRecorder
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        messageRecorder.record(
            rollout,
            input: inputResolver.input(for: rollout.payload),
            state: state
        )
    }
}
