import Foundation
import Testing
@testable import ClaudeUsageBarLib

@Suite("SessionStatsAggregator")
struct SessionStatsAggregatorTests {

    // MARK: - Helpers

    private func writeTempJSONL(_ content: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".jsonl")
        try! content.data(using: .utf8)!.write(to: url)
        return url
    }

    private func aggregate(_ jsonl: String) -> SessionStats {
        let messages = LogParser().parseMessages(at: writeTempJSONL(jsonl))
        return SessionStatsAggregator(messages: messages).aggregate()
    }

    private func aggregateByDay(_ jsonl: String, fallbackDay: String) -> [String: SessionStats] {
        let messages = LogParser().parseMessages(at: writeTempJSONL(jsonl))
        return SessionStatsAggregator(messages: messages).aggregateByDay(fallbackDay: fallbackDay)
    }

    // MARK: - Built-in tool counts

    @Test("Built-in tool counts exclude MCP and hook chips")
    func builtInToolCountsExcludeMCPAndHookChips() {
        let stats = aggregate("""
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_1","name":"Bash","input":{"command":"echo hi","description":"test"}},{"type":"tool_use","id":"toolu_2","name":"mcp__ide__getDiagnostics","input":{}}]}}
        """)

        #expect(stats.tools.countsByName["Bash"] == 1)
        #expect(stats.tools.countsByName["mcp__ide__getDiagnostics"] == nil)
        #expect(stats.mcp.byServer["ide"]?.countsByTool["getDiagnostics"] == 1)
    }

    // MARK: - Token dedup

    @Test("Duplicate usage per message id counts once")
    func duplicateUsagePerMessageIDCountsOnce() {
        // Streamed partial + final line share one message.id and an identical usage blob.
        let stats = aggregate("""
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":100,"output_tokens":50},"content":[{"type":"text","text":"partial"}]}}
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":100,"output_tokens":50},"content":[{"type":"text","text":"partial final"}]}}
        """)

        #expect(stats.tokens.inputTokens == 100)
        #expect(stats.tokens.outputTokens == 50)
    }

    // MARK: - MCP payload volume

    @Test("MCP payload volume derived from known-length tool_result")
    func mcpPayloadVolumeFromKnownLengthToolResult() {
        let resultText = String(repeating: "a", count: 40) // 40 bytes -> 10 approx tokens
        let stats = aggregate("""
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_1","name":"mcp__ide__getDiagnostics","input":{}}]}}
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":[{"type":"text","text":"\(resultText)"}]}]}}
        """)

        #expect(stats.mcp.byServer["ide"]?.payloadBytesByTool["getDiagnostics"] == 40)
        #expect(stats.mcp.approxPayloadTokens == 10)
    }

    // MARK: - Cache-hit rate

    @Test("Cache-hit rate computed normally")
    func cacheHitRateNormal() {
        let stats = aggregate("""
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":0,"cache_read_input_tokens":90},"content":[{"type":"text","text":"hi"}]}}
        """)

        #expect(abs(stats.tokens.cacheHitRate - 0.9) < 0.0001)
    }

    @Test("Cache-hit rate is zero, not NaN, with no input activity")
    func cacheHitRateZeroDenominatorIsZeroNotNaN() {
        let stats = SessionTokenStats()
        #expect(stats.cacheHitRate == 0)
        #expect(!stats.cacheHitRate.isNaN)
    }

    // MARK: - Day bucketing

    @Test("aggregateByDay splits totals across days")
    func aggregateByDaySplitsAcrossDays() {
        let byDay = aggregateByDay("""
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":5},"content":[{"type":"text","text":"day one"}]},"timestamp":"2026-07-01T10:00:00.000Z"}
        {"type":"assistant","message":{"id":"msg_2","model":"claude-opus-4-6","usage":{"input_tokens":20,"output_tokens":15},"content":[{"type":"text","text":"day two"}]},"timestamp":"2026-07-02T10:00:00.000Z"}
        """, fallbackDay: "2026-06-30")

        #expect(byDay["2026-07-01"]?.tokens.inputTokens == 10)
        #expect(byDay["2026-07-02"]?.tokens.inputTokens == 20)
    }

    @Test("Cross-day MCP call is attributed to the tool_use day")
    func aggregateByDayCrossDayMCPCallAttributedToToolUseDay() {
        let byDay = aggregateByDay("""
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":5},"content":[{"type":"tool_use","id":"toolu_1","name":"mcp__ide__getDiagnostics","input":{}}]},"timestamp":"2026-07-01T23:59:59.000Z"}
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":[{"type":"text","text":"done"}]}]},"timestamp":"2026-07-02T00:00:01.000Z"}
        """, fallbackDay: "2026-06-30")

        #expect(byDay["2026-07-01"]?.mcp.byServer["ide"]?.countsByTool["getDiagnostics"] == 1)
        #expect(byDay["2026-07-02"]?.mcp.byServer["ide"] == nil)
    }

    @Test("Nil timestamp carries forward the previous message's day")
    func aggregateByDayNilTimestampCarriesForwardPreviousDay() {
        let byDay = aggregateByDay("""
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":5},"content":[{"type":"text","text":"first"}]},"timestamp":"2026-07-01T10:00:00.000Z"}
        {"type":"user","message":{"role":"user","content":"no timestamp here"}}
        """, fallbackDay: "2026-06-30")

        #expect(byDay["2026-06-30"] == nil)
        #expect(byDay["2026-07-01"] != nil)
    }

    @Test("Falls back to the given day when no timestamp has been seen yet")
    func aggregateByDayFallsBackWhenNoTimestampSeenYet() {
        let byDay = aggregateByDay("""
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":5},"content":[{"type":"tool_use","id":"toolu_1","name":"Bash","input":{"command":"echo hi","description":"test"}}]}}
        """, fallbackDay: "2026-06-30")

        #expect(byDay["2026-06-30"]?.tools.countsByName["Bash"] == 1)
    }
}
