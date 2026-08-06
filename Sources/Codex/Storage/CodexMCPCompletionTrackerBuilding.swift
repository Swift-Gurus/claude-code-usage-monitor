import Foundation

/**
 solid-name: CodexMCPCompletionTrackerBuilding
 solid-category: abstraction
 solid-description: Contract for building MCP completion reservations from Codex rollouts.
 */
protocol CodexMCPCompletionTrackerBuilding {
    func makeTracker(rollouts: [CodexTimestampedRollout]) -> CodexMCPCompletionTracking
}
