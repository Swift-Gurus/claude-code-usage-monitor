import Foundation

/**
 solid-name: CodexLogParseStateBuilder
 solid-category: service
 solid-description: Creates fresh state for a Codex log parse.
 */
struct CodexLogParseStateBuilder: CodexLogParseStateBuilding {
    private let completionTrackerBuilder: CodexMCPCompletionTrackerBuilding

    init(completionTrackerBuilder: CodexMCPCompletionTrackerBuilding = CodexMCPCompletionTrackerBuilder()) {
        self.completionTrackerBuilder = completionTrackerBuilder
    }

    func makeState(rollouts: [CodexTimestampedRollout]) -> CodexLogParseState {
        CodexLogParseState(
            mcpCompletions: completionTrackerBuilder.makeTracker(rollouts: rollouts)
        )
    }
}
