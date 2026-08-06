import Foundation
@testable import ClaudeUsageBarLib

/**
 solid-name: StatsFileAggregatorStub
 solid-category: test-double
 solid-stack: [structured-concurrency]
 solid-description: Supplies fixed daily session statistics to stats page tests.
 */
struct StatsFileAggregatorStub: StatsFileAggregating {
    let statsByDay: [String: SessionStats]

    func aggregate(files: Set<StatsSessionFile>) async -> [String: SessionStats] {
        statsByDay
    }
}
