import Foundation

/**
 solid-name: CodexEventParsing
 solid-category: abstraction
 solid-description: Contract for parsing Codex event rollouts into message state.
 */
protocol CodexEventParsing {
    func parse(_ rollout: CodexTimestampedRollout, state: CodexLogParseState)
}
