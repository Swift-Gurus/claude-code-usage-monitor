import Foundation
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexRolloutStoreStub
 solid-category: test-double
 solid-description: Supplies fixed Codex rollout files to resolver tests.
 */
struct CodexRolloutStoreStub: CodexRolloutReading {
    let urls: [URL]

    func indexedSessionTitles() -> [String: String] { [:] }
    func rolloutURLs(modifiedSince date: Date) -> [URL] { urls }
    func rolloutURL(threadID: String) -> URL? { nil }
    func rolloutEvents(threadID: String, limit: Int) -> [CodexRolloutEvent] { [] }
    func parsedRollout(threadID: String, fallbackTitle: String) -> CodexParsedRollout? { nil }
    func recentParsedRollouts(
        now: Date,
        threshold: TimeInterval,
        titlesByID: [String: String]
    ) -> [String: CodexParsedRollout] { [:] }
}
