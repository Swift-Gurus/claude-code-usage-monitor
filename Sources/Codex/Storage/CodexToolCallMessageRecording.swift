import Foundation

/**
 solid-name: CodexToolCallMessageRecording
 solid-category: abstraction
 solid-description: Contract for recording Codex tool invocations as indexed log messages.
 */
protocol CodexToolCallMessageRecording {
    func record(
        _ rollout: CodexTimestampedRollout,
        input: [String: Any],
        state: CodexLogParseState
    )
}
