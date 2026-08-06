import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexUserMessageDeduplicationTests
 solid-category: unit-test
 solid-description: Verifies mirrored Codex user records produce one visible log message.
 */
@Suite("Codex User Message Deduplication")
struct CodexUserMessageDeduplicationTests {
    private let scenarioRunner: CodexMessagesScenarioRunning = CodexMessagesScenarioRunner()

    @Test("Mirrored records produce one visible message")
    func mirroredRecordsProduceOneVisibleMessage() throws {
        let messages = try scenarioRunner.messages(#"""
        {"timestamp":"2026-08-05T19:52:33.588Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Run the requested review\n"}]}}
        {"timestamp":"2026-08-05T19:52:33.588Z","type":"event_msg","payload":{"type":"user_message","message":"Run the requested review\n"}}
        """#)

        let matchingMessages = messages.filter { $0.role == .user }

        #expect(matchingMessages.count == 1)
    }
}
