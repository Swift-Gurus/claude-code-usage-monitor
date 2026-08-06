import Foundation

/**
 solid-name: CodexResponseItemHandling
 solid-category: abstraction
 solid-description: Contract for applying one kind of Codex response item to parse state.
 */
protocol CodexResponseItemHandling {
    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState)
}
