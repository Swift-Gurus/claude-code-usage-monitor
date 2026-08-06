import Foundation

/**
 solid-name: CodexResponseItemParsing
 solid-category: abstraction
 solid-description: Contract for parsing Codex response-item rollouts into message state.
 */
protocol CodexResponseItemParsing {
    func parse(_ rollout: CodexTimestampedRollout, state: CodexLogParseState)
}
