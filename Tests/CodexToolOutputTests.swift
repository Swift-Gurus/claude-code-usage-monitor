import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexToolOutputTests
 solid-category: unit-test
 solid-description: Verifies Codex tool output strings and content-block arrays attach as complete result text.
 */
@Suite("Codex Tool Output")
struct CodexToolOutputTests {
    private let scenarioRunner: CodexMessagesScenarioRunning = CodexMessagesScenarioRunner()

    @Test("Array output attaches every text block")
    func arrayOutputAttachesEveryTextBlock() throws {
        let messages = try scenarioRunner.messages("""
        {"timestamp":"2026-08-05T19:52:55.000Z","type":"response_item","payload":{"type":"custom_tool_call","name":"exec","input":"run task","call_id":"call-1"}}
        {"timestamp":"2026-08-05T19:52:56.000Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"call-1","output":[{"type":"input_text","text":"first block"},{"type":"input_text","text":"second block"}]}}
        """)

        let output = messages.flatMap { $0.toolResultContents.values }.joined(separator: "\n")

        #expect(output.contains("first block"))
        #expect(output.contains("second block"))
    }
}
