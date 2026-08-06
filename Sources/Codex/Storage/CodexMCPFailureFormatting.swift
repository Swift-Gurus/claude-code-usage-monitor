import Foundation

/**
 solid-name: CodexMCPFailureFormatting
 solid-category: abstraction
 solid-description: Contract for formatting failed MCP result content and status.
 */
protocol CodexMCPFailureFormatting {
    func format(_ failure: JSONValue) -> [String]
}
