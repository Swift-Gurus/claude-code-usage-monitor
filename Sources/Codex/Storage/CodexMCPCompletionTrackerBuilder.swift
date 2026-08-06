import Foundation

/**
 solid-name: CodexMCPCompletionTrackerBuilder
 solid-category: service
 solid-description: Builds MCP completion reservations from Codex rollouts.
 */
struct CodexMCPCompletionTrackerBuilder: CodexMCPCompletionTrackerBuilding {
    private let toolNameResolver: CodexMCPToolNameResolving

    init(toolNameResolver: CodexMCPToolNameResolving = CodexMCPToolNameResolver()) {
        self.toolNameResolver = toolNameResolver
    }

    func makeTracker(rollouts: [CodexTimestampedRollout]) -> CodexMCPCompletionTracking {
        var countsByToolName: [String: Int] = [:]
        for rollout in rollouts where rollout.payload.type == "mcp_tool_call_end" {
            guard let invocation = rollout.payload.invocation else { continue }
            countsByToolName[toolNameResolver.name(for: invocation), default: 0] += 1
        }
        return CodexMCPCompletionTracker(countsByToolName: countsByToolName)
    }
}
