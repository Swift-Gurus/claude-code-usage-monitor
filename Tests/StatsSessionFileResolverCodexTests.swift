import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: StatsSessionFileResolverCodexTests
 solid-category: unit-test
 solid-description: Verifies stats session resolution includes Codex rollouts with Claude transcripts.
 */
@Suite("Stats Session File Resolver Codex Support")
struct StatsSessionFileResolverCodexTests {
    @Test("Resolver includes Codex rollouts alongside Claude transcripts")
    func includesCodexRolloutsAlongsideClaudeTranscripts() async {
        let claudeURL = URL(fileURLWithPath: "/tmp/claude-session.jsonl")
        let codexURL = URL(fileURLWithPath: "/tmp/codex-rollout.jsonl")
        let resolver = StatsSessionFileResolver(
            workingDirCollector: CodexWorkingDirCollectorStub(),
            sessionResolver: CodexSessionResolverStub(url: claudeURL),
            codexRolloutStore: CodexRolloutStoreStub(urls: [codexURL])
        )

        let files = await resolver.resolveFiles(accounts: [.default], monthStart: .distantPast)

        #expect(files == Set([
            StatsSessionFile(url: claudeURL, format: .claude),
            StatsSessionFile(url: codexURL, format: .codex)
        ]))
    }
}
