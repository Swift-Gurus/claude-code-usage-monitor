import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: SourceAwareStatsAggregationTests
 solid-category: unit-test
 solid-description: Verifies Claude and Codex session files combine into source-aware daily statistics.
 */
@Suite("Source-Aware Stats Aggregation")
struct SourceAwareStatsAggregationTests {
    private let directoryProvider: TemporaryDirectoryProviding = IsolatedTemporaryDirectoryProvider()

    @Test("Claude and Codex stats combine by day")
    func combinesClaudeAndCodexStats() async throws {
        let stats = try await directoryProvider.withDirectory { directory in
            let claudeURL = directory.appendingPathComponent("claude.jsonl")
            try Data("""
            {"type":"assistant","timestamp":"2026-08-04T09:00:00.000Z","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":5},"content":[{"type":"tool_use","id":"tool_1","name":"Bash","input":{"command":"echo hi"}}]}}
            """.utf8).write(to: claudeURL)
            let codexURL = directory.appendingPathComponent("codex.jsonl")
            try Data("""
            {"timestamp":"2026-08-04T10:00:00.000Z","type":"response_item","payload":{"type":"function_call","name":"exec","input":"echo hi","call_id":"call_1"}}
            {"timestamp":"2026-08-04T10:00:01.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":40,"cache_write_input_tokens":0,"output_tokens":20,"total_tokens":120}}}}
            """.utf8).write(to: codexURL)
            let files: Set<StatsSessionFile> = [
                StatsSessionFile(url: claudeURL, format: .claude),
                StatsSessionFile(url: codexURL, format: .codex)
            ]

            return await StatsFileAggregator().aggregate(files: files)["2026-08-04"]
        }
        let combined = try #require(stats)

        #expect(combined.tools.countsByName["Bash"] == 1)
        #expect(combined.tools.countsByName["exec"] == 1)
        #expect(combined.tokens.inputTokens == 70)
        #expect(combined.tokens.outputTokens == 25)
        #expect(combined.tokens.cacheReadTokens == 40)
    }
}
