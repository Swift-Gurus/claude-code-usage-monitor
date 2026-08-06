import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexReasoningContextTests
 solid-category: unit-test
 solid-description: Verifies Codex reasoning context remains visible without mirrored summary duplication.
 */
@Suite("Codex Reasoning Context")
struct CodexReasoningContextTests {
    private let scenarioRunner: CodexMessagesScenarioRunning = CodexMessagesScenarioRunner()

    @Test("Mirrored reasoning summary is not duplicated")
    func mirroredSummaryIsNotDuplicated() throws {
        let messages = try scenarioRunner.messages("""
        {"timestamp":"2026-08-05T19:52:36.698Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"Designing JSON-formatted responses"}}
        {"timestamp":"2026-08-05T19:52:36.698Z","type":"response_item","payload":{"type":"reasoning","summary":[{"type":"summary_text","text":"Designing JSON-formatted responses"}]}}
        """)

        #expect(messages.compactMap(\.thinking) == ["Designing JSON-formatted responses"])
    }

    @Test("Combined summary does not repeat individual reasoning events")
    func combinedSummaryDoesNotRepeatEvents() throws {
        let messages = try scenarioRunner.messages("""
        {"timestamp":"2026-08-05T19:52:36.700Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"Planning tool discovery"}}
        {"timestamp":"2026-08-05T19:52:36.710Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"Clarifying tool requirements"}}
        {"timestamp":"2026-08-05T19:52:36.710Z","type":"response_item","payload":{"type":"reasoning","summary":[{"type":"summary_text","text":"Planning tool discovery\nClarifying tool requirements"}]}}
        """)

        #expect(messages.compactMap(\.thinking) == [
            "Planning tool discovery",
            "Clarifying tool requirements"
        ])
    }

    @Test("Event-only reasoning remains visible")
    func eventOnlyReasoningRemainsVisible() throws {
        let messages = try scenarioRunner.messages("""
        {"timestamp":"2026-08-05T19:52:36.698Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"Inspecting hook requirements"}}
        """)

        #expect(messages.compactMap(\.thinking) == ["Inspecting hook requirements"])
    }
}
