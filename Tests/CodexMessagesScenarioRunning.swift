import Foundation
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexMessagesScenarioRunning
 solid-category: abstraction
 solid-description: Contract for parsing Codex JSONL test scenarios into log messages.
 */
protocol CodexMessagesScenarioRunning {
    func messages(_ content: String) throws -> [LogMessage]
}
