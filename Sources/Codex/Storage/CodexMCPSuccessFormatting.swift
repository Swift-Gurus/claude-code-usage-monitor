import Foundation

/**
 solid-name: CodexMCPSuccessFormatting
 solid-category: abstraction
 solid-description: Contract for formatting successful MCP result content and status.
 */
protocol CodexMCPSuccessFormatting {
    func format(_ result: CodexMCPResult) -> [String]
}
