import Foundation

/**
 solid-name: CodexMCPCompletionTracker
 solid-category: service
 solid-description: Reserves authoritative MCP completion records against earlier mirrored tool calls.
 */
final class CodexMCPCompletionTracker: CodexMCPCompletionTracking {
    private var countsByToolName: [String: Int]

    init(countsByToolName: [String: Int]) {
        self.countsByToolName = countsByToolName
    }

    func consumeReservation(for toolName: String) -> Bool {
        guard let count = countsByToolName[toolName], count > 0 else { return false }
        countsByToolName[toolName] = count - 1
        return true
    }
}
