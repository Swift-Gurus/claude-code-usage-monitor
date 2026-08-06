import Foundation

/**
 solid-name: CodexToolCallCanonicalizing
 solid-category: abstraction
 solid-description: Contract for removing MCP tool calls represented by authoritative completion records.
 */
protocol CodexToolCallCanonicalizing {
    func canonicalCalls(
        from calls: [LogToolCall],
        completions: CodexMCPCompletionTracking
    ) -> [LogToolCall]
}
