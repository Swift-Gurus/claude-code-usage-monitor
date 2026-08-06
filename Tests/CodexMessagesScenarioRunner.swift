import Foundation
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexMessagesScenarioRunner
 solid-category: unit-test
 solid-description: Parses isolated Codex JSONL test scenarios into log messages.
 */
struct CodexMessagesScenarioRunner: CodexMessagesScenarioRunning {
    private let fixtureProvider: JSONLFixtureProviding
    private let parser: LogMessageParsing

    init(
        fixtureProvider: JSONLFixtureProviding = TemporaryJSONLFixtureProvider(),
        parser: LogMessageParsing = CodexLogParser()
    ) {
        self.fixtureProvider = fixtureProvider
        self.parser = parser
    }

    func messages(_ content: String) throws -> [LogMessage] {
        try fixtureProvider.withFixture(content: content) { url in
            parser.parseMessages(at: url)
        }
    }
}
