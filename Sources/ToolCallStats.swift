import Foundation

/// Built-in tool call counts by name (excludes MCP tools and synthesized hook chips).
public struct ToolCallStats: Equatable, Sendable {
    public var countsByName: [String: Int] = [:]

    public var total: Int { countsByName.values.reduce(0, +) }

    public init(countsByName: [String: Int] = [:]) {
        self.countsByName = countsByName
    }

    public mutating func merge(_ other: ToolCallStats) {
        for (name, count) in other.countsByName {
            countsByName[name, default: 0] += count
        }
    }
}
