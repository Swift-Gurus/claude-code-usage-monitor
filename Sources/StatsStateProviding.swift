/**
 solid-name: StatsStateProviding
 solid-category: abstraction
 solid-description: Contract that provides session statistics.
 */
protocol StatsStateProviding {
    var sessionStats: SessionStats { get }
}