import Foundation

/// Formats a date into a `yyyy-MM-dd` day key, injectable so `SessionStatsAggregator`
/// isn't hardwired to a concrete `DateFormatter`.
public protocol DayFormatting {
    func dayString(from date: Date) -> String
}

/// `DateFormatter`-backed `DayFormatting`, matching the `yyyy-MM-dd` convention used
/// elsewhere in the app (e.g. `AgentTracker`, `UsageEntryCollector`).
public struct DayFormatter: DayFormatting {
    private let formatter: DateFormatter

    public init() {
        formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
    }

    public func dayString(from date: Date) -> String {
        formatter.string(from: date)
    }
}

/// Builds `SessionStats` from parsed log messages. Tool calls are attributed by
/// scanning `toolCalls` directly; hook-synthesized chips are excluded and MCP calls
/// are split out from built-in tool counts. Token totals rely on `LogMessage.usage`
/// already being deduped by message id upstream (see `MessageBuilder`).
public struct SessionStatsAggregator {
    private let messages: [LogMessage]
    private let dayFormatter: DayFormatting

    public init(messages: [LogMessage], dayFormatter: DayFormatting = DayFormatter()) {
        self.messages = messages
        self.dayFormatter = dayFormatter
    }

    /// Whole-file totals, used by the log-viewer inline panel. Delegates to
    /// `aggregateByDay` and folds every bucket together, since day partitioning
    /// doesn't change the additive totals.
    public func aggregate() -> SessionStats {
        aggregateByDay(fallbackDay: "").values.reduce(into: SessionStats()) { $0.merge($1) }
    }

    /// Buckets by the calendar day of each message's own timestamp. A message with no
    /// timestamp inherits the previous message's day; if none seen yet, falls back to
    /// `fallbackDay`. An MCP call whose tool_use and tool_result straddle a day
    /// boundary is attributed to the tool_use day, since that's the message being
    /// bucketed when the call is counted.
    public func aggregateByDay(fallbackDay: String) -> [String: SessionStats] {
        var byDay: [String: SessionStats] = [:]
        let resultContentByToolUseID = resultContentLookup()
        var currentDay = fallbackDay
        for message in messages {
            if let timestamp = message.timestamp {
                currentDay = dayFormatter.dayString(from: timestamp)
            }
            accumulate(message, resultContentByToolUseID: resultContentByToolUseID, into: &byDay[currentDay, default: SessionStats()])
        }
        return byDay
    }

    /// A tool_result can land on a later JSONL line than its tool_use, so this is
    /// resolved once across all messages before walking them for counts.
    private func resultContentLookup() -> [String: String] {
        var lookup: [String: String] = [:]
        for message in messages {
            for (toolUseID, content) in message.toolResultContents {
                lookup[toolUseID] = content
            }
        }
        return lookup
    }

    private func accumulate(_ message: LogMessage, resultContentByToolUseID: [String: String], into stats: inout SessionStats) {
        for toolCall in message.toolCalls {
            switch toolCall.data {
            case .hook:
                continue
            case .mcp(let data):
                recordMCPCall(data, toolUseID: toolCall.id, resultContentByToolUseID: resultContentByToolUseID, into: &stats.mcp)
            default:
                stats.tools.countsByName[toolCall.name, default: 0] += 1
            }
        }
        if let usage = message.usage {
            stats.tokens.add(usage)
        }
    }

    private func recordMCPCall(_ data: MCPToolData, toolUseID: String, resultContentByToolUseID: [String: String], into mcp: inout MCPCallStats) {
        mcp.byServer[data.serverName, default: MCPCallStats.ServerStats()].countsByTool[data.toolName, default: 0] += 1
        if let content = resultContentByToolUseID[toolUseID] {
            mcp.byServer[data.serverName, default: MCPCallStats.ServerStats()].payloadBytesByTool[data.toolName, default: 0] += content.utf8.count
        }
    }
}
