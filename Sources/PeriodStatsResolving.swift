import Foundation

/// Resolves the `PeriodStats` for a "Today"/"Week"/"Month" label.
protocol PeriodStatsResolving {
    func stats(for label: String) -> PeriodStats
}
