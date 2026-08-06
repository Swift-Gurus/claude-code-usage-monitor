import Foundation

/**
 solid-name: CodexToolCallCanonicalizer
 solid-category: service
 solid-description: Removes MCP tool calls represented by authoritative completion records.
 */
struct CodexToolCallCanonicalizer: CodexToolCallCanonicalizing {
    func canonicalCalls(
        from calls: [LogToolCall],
        completions: CodexMCPCompletionTracking
    ) -> [LogToolCall] {
        calls.filter { call in
            guard call.name.hasPrefix("mcp__") else { return true }
            return !completions.consumeReservation(for: call.name)
        }
    }
}
