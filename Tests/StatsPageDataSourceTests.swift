import Foundation
import Observation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: StatsPageDataSourceTests
 solid-category: unit-test
 solid-stack: [structured-concurrency]
 solid-description: Verifies stats page loading publishes aggregate period totals.
 */
@Suite("Stats Page Data Source")
struct StatsPageDataSourceTests {
    @Test("Loaded totals replace the zero state")
    @MainActor
    func publishesLoadedTotals() async {
        let dayKey = DayFormatter().dayString(from: Date())
        let expected = SessionStats(tokens: SessionTokenStats(inputTokens: 42))
        let dataSource = StatsPageDataSource(
            accounts: [],
            fileResolver: EmptyStatsSessionFileResolverStub(),
            fileAggregator: StatsFileAggregatorStub(statsByDay: [dayKey: expected])
        )

        dataSource.reload()
        #expect(dataSource.isLoading)
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = dataSource.isLoading
            } onChange: {
                continuation.resume()
            }
        }

        #expect(dataSource.day.tokens.inputTokens == 42)
    }
}
