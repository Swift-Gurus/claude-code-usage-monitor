import Foundation

/// Tool-call, MCP-call, and token/cache stats for one or more JSONL transcripts.
/// Used both for a single file (log-viewer inline panel) and additively merged across
/// many files (the Stats page) — the scope difference lives in how many files feed in,
/// not in this type.
public struct SessionStats: Equatable, Sendable {
    public var tools = ToolCallStats()
    public var mcp = MCPCallStats()
    public var tokens = SessionTokenStats()

    public init(tools: ToolCallStats = ToolCallStats(), mcp: MCPCallStats = MCPCallStats(), tokens: SessionTokenStats = SessionTokenStats()) {
        self.tools = tools
        self.mcp = mcp
        self.tokens = tokens
    }

    public mutating func merge(_ other: SessionStats) {
        tools.merge(other.tools)
        mcp.merge(other.mcp)
        tokens.merge(other.tokens)
    }
}
