/**
 solid-name: StatsRollupProviding
 solid-category: abstraction
 solid-description: Contract for aggregating statistics data into structured time-period summaries.
 */
protocol StatsRollupProviding: Sendable {
    func rollup(statsByDay: [String: SessionStats], boundaries: PeriodBoundaries) -> DayBucketedStatsRollup
}

/**
 solid-name: DefaultStatsRollupProvider
 solid-category: service
 solid-description: Aggregates statistics data into structured time-period summaries.
 */
struct DefaultStatsRollupProvider: StatsRollupProviding {
    func rollup(statsByDay: [String: SessionStats], boundaries: PeriodBoundaries) -> DayBucketedStatsRollup {
        DayBucketedStatsRollup(statsByDay: statsByDay, boundaries: boundaries)
    }
}
