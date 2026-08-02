import Foundation

/**
 solid-name: StatsPageDataSource
 solid-category: viewmodel
 solid-stack: [structured-concurrency]
 solid-description: Provides session statistics aggregated by time period.
 */
@Observable
final class StatsPageDataSource: StatsPageState, StatsPageActions {
    private(set) var day = SessionStats()
    private(set) var week = SessionStats()
    private(set) var month = SessionStats()

    private let accounts: [Account]
    private let fileResolver: StatsSessionFileResolving
    private let fileAggregator: StatsFileAggregating
    private let boundariesProvider: PeriodBoundariesProviding
    private let rollupProvider: StatsRollupProviding
    private let runner = ReloadTaskRunner()

    init(
        accounts: [Account],
        fileResolver: StatsSessionFileResolving = StatsSessionFileResolver(),
        fileAggregator: StatsFileAggregating = StatsFileAggregator(),
        boundariesProvider: PeriodBoundariesProviding = DefaultPeriodBoundariesProvider(),
        rollupProvider: StatsRollupProviding = DefaultStatsRollupProvider()
    ) {
        self.accounts = accounts
        self.fileResolver = fileResolver
        self.fileAggregator = fileAggregator
        self.boundariesProvider = boundariesProvider
        self.rollupProvider = rollupProvider
    }

    func reload() {
        let accountsSnapshot = accounts
        let resolver = fileResolver
        let aggregator = fileAggregator
        let rollupProvider = rollupProvider
        let boundaries = boundariesProvider.boundaries(now: Date())

        runner.run { [weak self] in
            let files = resolver.resolveFiles(accounts: accountsSnapshot, monthStart: boundaries.monthStart)
            let statsByDay = aggregator.aggregate(files: files)
            let rollup = rollupProvider.rollup(statsByDay: statsByDay, boundaries: boundaries)

            await MainActor.run {
                self?.day = rollup.day
                self?.week = rollup.week
                self?.month = rollup.month
            }
        }
    }
}
