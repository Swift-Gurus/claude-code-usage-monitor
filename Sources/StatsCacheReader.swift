import Foundation

/**
 solid-name: StatsCacheReading
 solid-category: abstraction
 solid-description: Contract for reading cached Claude usage statistics for an account directory.
 */
protocol StatsCacheReading: Sendable {
    func read(claudeDirectory: String) -> StatsCache?
}

/**
 solid-name: StatsCacheReader
 solid-category: crud
 solid-description: Reads cached Claude usage statistics for account dashboards and usage summaries.
 */
struct StatsCacheReader: StatsCacheReading {
    func read(claudeDirectory: String) -> StatsCache? {
        StatsCache.load(claudeDir: claudeDirectory)
    }
}
