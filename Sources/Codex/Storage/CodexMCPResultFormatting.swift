import Foundation

/**
 solid-name: CodexMCPResultFormatting
 solid-category: abstraction
 solid-description: Contract for formatting MCP completion results, status, and duration as display text.
 */
protocol CodexMCPResultFormatting {
    func format(payload: CodexRolloutPayload) -> String?
}
