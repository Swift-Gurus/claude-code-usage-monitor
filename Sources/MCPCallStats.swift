import Foundation

/// MCP tool call counts and approximate result-payload volume, grouped by server then tool.
public struct MCPCallStats: Equatable, Sendable {
    public struct ServerStats: Equatable, Sendable {
        public var countsByTool: [String: Int] = [:]
        /// utf8 byte length of tool_result content returned for each tool, summed.
        public var payloadBytesByTool: [String: Int] = [:]

        public var total: Int { countsByTool.values.reduce(0, +) }

        public init(countsByTool: [String: Int] = [:], payloadBytesByTool: [String: Int] = [:]) {
            self.countsByTool = countsByTool
            self.payloadBytesByTool = payloadBytesByTool
        }

        public mutating func merge(_ other: ServerStats) {
            for (tool, count) in other.countsByTool {
                countsByTool[tool, default: 0] += count
            }
            for (tool, bytes) in other.payloadBytesByTool {
                payloadBytesByTool[tool, default: 0] += bytes
            }
        }
    }

    public var byServer: [String: ServerStats] = [:]

    public var total: Int { byServer.values.reduce(0) { $0 + $1.total } }

    /// Approximate token count of MCP result payloads (~4 bytes/token heuristic).
    /// Not an exact billed-token figure — schema-definition overhead isn't observable
    /// from local JSONL logs, only the result content actually returned.
    public var approxPayloadTokens: Int {
        byServer.values.reduce(0) { $0 + $1.payloadBytesByTool.values.reduce(0, +) } / 4
    }

    public init(byServer: [String: ServerStats] = [:]) {
        self.byServer = byServer
    }

    public mutating func merge(_ other: MCPCallStats) {
        for (server, stats) in other.byServer {
            byServer[server, default: ServerStats()].merge(stats)
        }
    }
}
