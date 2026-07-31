import Foundation

public struct LogMessage: Identifiable {
    /// Compatibility alias — the role enum lives at top level as `LogRole` (its own
    /// file, per one-type-per-file), but existing call sites spell it `LogMessage.Role`.
    public typealias Role = LogRole

    public let id: String
    public let role: LogRole
    public let model: String?
    public let timestamp: Date?
    public let thinking: String?
    public let textContent: [String]
    public let toolCalls: [LogToolCall]
    /// tool_use_ids that have been resolved via tool_result (user messages only).
    public let toolResultIDs: Set<String>
    /// User's structured responses to interactive prompts, keyed by tool_use_id.
    public let toolResponses: [String: ToolResponse]
    /// Tool result text content keyed by tool_use_id (user messages only).
    public let toolResultContents: [String: String]
    /// Token usage for this assistant turn, deduped by message id (nil for non-assistant roles).
    public var usage: TokenUsage? = nil
}
