import Foundation

/**
 solid-name: CodexEventHandling
 solid-category: abstraction
 solid-description: Contract for applying one kind of Codex event to parse state.
 */
protocol CodexEventHandling {
    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState)
}
