import Foundation

/**
 solid-name: CodexLogParseStateBuilding
 solid-category: abstraction
 solid-description: Contract for creating fresh state for a Codex log parse.
 */
protocol CodexLogParseStateBuilding {
    func makeState(rollouts: [CodexTimestampedRollout]) -> CodexLogParseState
}
