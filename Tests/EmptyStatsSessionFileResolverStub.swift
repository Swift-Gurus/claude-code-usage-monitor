import Foundation
@testable import ClaudeUsageBarLib

/**
 solid-name: EmptyStatsSessionFileResolverStub
 solid-category: test-double
 solid-stack: [structured-concurrency]
 solid-description: Supplies an empty session-file set to stats page tests.
 */
struct EmptyStatsSessionFileResolverStub: StatsSessionFileResolving {
    func resolveFiles(accounts: [Account], monthStart: Date) async -> Set<StatsSessionFile> {
        []
    }
}
