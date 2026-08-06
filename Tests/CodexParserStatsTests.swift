import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexParserStatsTests
 solid-category: unit-test
 solid-description: Verifies Codex rollout parsing produces token and MCP statistics.
 */
@Suite("Codex Parser Stats")
struct CodexParserStatsTests {
    private let scenarioRunner: CodexStatsScenarioRunning = CodexStatsScenarioRunner()

    @Test("Cumulative token counts produce additive deltas")
    func cumulativeTokenCountsProduceAdditiveDeltas() throws {
        let stats = try scenarioRunner.aggregate("""
        {"timestamp":"2026-08-04T10:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":40,"cache_write_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}
        {"timestamp":"2026-08-04T10:01:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":180,"cached_input_tokens":70,"cache_write_input_tokens":15,"output_tokens":35,"total_tokens":215}}}}
        {"timestamp":"2026-08-04T10:02:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":170,"cached_input_tokens":60,"cache_write_input_tokens":10,"output_tokens":30,"total_tokens":200}}}}
        """)

        #expect(stats.tokens.inputTokens == 95)
        #expect(stats.tokens.outputTokens == 35)
        #expect(stats.tokens.cacheCreationTokens == 15)
        #expect(stats.tokens.cacheReadTokens == 70)
    }

    @Test("MCP namespaces and outputs produce grouped payload stats")
    func mcpNamespacesAndOutputsProduceGroupedPayloadStats() throws {
        let payload = String(repeating: "a", count: 40)
        let stats = try scenarioRunner.aggregate("""
        {"timestamp":"2026-08-04T10:00:00.000Z","type":"response_item","payload":{"type":"function_call","name":"load_rules","namespace":"mcp__solid_coder_docs__","arguments":"{}","call_id":"call_1"}}
        {"timestamp":"2026-08-04T10:00:01.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"call_1","output":"\(payload)"}}
        """)

        #expect(stats.mcp.byServer["solid_coder_docs"]?.countsByTool["load_rules"] == 1)
        #expect(stats.mcp.byServer["solid_coder_docs"]?.payloadBytesByTool["load_rules"] == 40)
        #expect(stats.tools.total == 0)
    }

    @Test("Exec wrappers expose nested MCP calls to stats")
    func execWrappersExposeNestedMCPCallsToStats() throws {
        let payload = String(repeating: "b", count: 32)
        let stats = try scenarioRunner.aggregate("""
        {"timestamp":"2026-08-04T10:00:00.000Z","type":"response_item","payload":{"type":"custom_tool_call","name":"exec","input":"const r = await tools.mcp__pipeline__search_codebase({}); text(r);","call_id":"call_1"}}
        {"timestamp":"2026-08-04T10:00:01.000Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"call_1","output":"\(payload)"}}
        """)

        #expect(stats.mcp.byServer["pipeline"]?.countsByTool["search_codebase"] == 1)
        #expect(stats.mcp.byServer["pipeline"]?.payloadBytesByTool["search_codebase"] == 32)
        #expect(stats.tools.countsByName["exec"] == nil)
    }
}
