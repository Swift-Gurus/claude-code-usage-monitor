import Foundation

/**
 solid-name: CodexMCPCompletionTracking
 solid-category: abstraction
 solid-description: Contract for reserving authoritative MCP completion records against earlier mirrored tool calls.
 */
protocol CodexMCPCompletionTracking: AnyObject {
    func consumeReservation(for toolName: String) -> Bool
}
