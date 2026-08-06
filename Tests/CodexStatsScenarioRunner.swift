import Foundation
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexStatsScenarioRunner
 solid-category: test-fixture
 solid-description: Produces aggregate statistics from isolated Codex JSONL test scenarios.
 */
struct CodexStatsScenarioRunner: CodexStatsScenarioRunning {
    private let fixtureProvider: JSONLFixtureProviding
    private let parser: LogMessageParsing

    init(
        fixtureProvider: JSONLFixtureProviding = TemporaryJSONLFixtureProvider(),
        parser: LogMessageParsing = CodexLogParser()
    ) {
        self.fixtureProvider = fixtureProvider
        self.parser = parser
    }

    func aggregate(_ content: String) throws -> SessionStats {
        try fixtureProvider.withFixture(content: content) { url in
            SessionStatsAggregator(messages: parser.parseMessages(at: url)).aggregate()
        }
    }
}
