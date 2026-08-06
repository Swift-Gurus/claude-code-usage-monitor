import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexMCPCompletionTests
 solid-category: unit-test
 solid-description: Verifies authoritative MCP completion events retain invocation and result context without duplicate calls.
 */
@Suite("Codex MCP Completion")
struct CodexMCPCompletionTests {
    private let scenarioRunner: CodexMessagesScenarioRunning = CodexMessagesScenarioRunner()

    @Test("Completion retains context once")
    func completionRetainsContextOnce() throws {
        let messages = try scenarioRunner.messages(#"""
        {"timestamp":"2026-08-05T19:52:55.000Z","type":"response_item","payload":{"type":"custom_tool_call","name":"exec","input":"const r = await tools.mcp__solid_coder_pipeline__submit_batch_findings({output_dir: \".\"}); text(r);","call_id":"outer-call"}}
        {"timestamp":"2026-08-05T19:52:56.986Z","type":"event_msg","payload":{"type":"mcp_tool_call_end","call_id":"exec-1","invocation":{"server":"solid-coder-pipeline","tool":"submit_batch_findings","arguments":{"output_dir":".","submissions":{}}},"duration":{"secs":0,"nanos":16721791},"result":{"Ok":{"content":[{"type":"text","text":"{\"violations\":[]}"}],"isError":false}}}}
        """#)
        let calls = messages.flatMap(\.toolCalls).filter { $0.name.hasPrefix("mcp__") }
        let resultText = messages.flatMap { $0.toolResultContents.values }.joined(separator: "\n")
        let stats = SessionStatsAggregator(messages: messages).aggregate()

        #expect(calls.count == 1)
        #expect(calls.first?.name == "mcp__solid_coder_pipeline__submit_batch_findings")
        #expect(resultText.contains("violations"))
        #expect(resultText.contains("duration"))
        #expect(stats.mcp.byServer["solid_coder_pipeline"]?.countsByTool["submit_batch_findings"] == 1)
        #expect((stats.mcp.byServer["solid_coder_pipeline"]?.payloadBytesByTool["submit_batch_findings"] ?? 0) > 0)
    }
}
