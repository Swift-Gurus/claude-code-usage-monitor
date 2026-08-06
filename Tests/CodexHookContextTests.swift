import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexHookContextTests
 solid-category: unit-test
 solid-description: Verifies Codex hook prompts retain requirement context as system messages.
 */
@Suite("Codex Hook Context")
struct CodexHookContextTests {
    private let scenarioRunner: CodexMessagesScenarioRunning = CodexMessagesScenarioRunner()

    @Test("Hook prompt retains requirement context")
    func hookPromptRetainsRequirementContext() throws {
        let messages = try scenarioRunner.messages(#"""
        {"timestamp":"2026-08-05T19:52:48.960Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<hook_prompt hook_run_id=\"stop:2:config.toml\">Required tool not called: mcp__pipeline__submit_batch_findings.</hook_prompt>"}]}}
        """#)

        let hook = try #require(messages.first)
        let context = hook.textContent.joined(separator: "\n")

        #expect(hook.role == .system)
        #expect(context.contains("Required tool not called"))
        #expect(context.contains("mcp__pipeline__submit_batch_findings"))
    }
}
