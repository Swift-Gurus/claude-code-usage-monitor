import Foundation

/**
 solid-name: CodexMCPCompletionMessageBuilding
 solid-category: abstraction
 solid-description: Contract for building rich log messages from authoritative MCP completion events.
 */
protocol CodexMCPCompletionMessageBuilding {
    func message(from rollout: CodexTimestampedRollout) -> LogMessage?
}
