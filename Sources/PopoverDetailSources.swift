/// Non-empty (CLI/Commander) sources for a period's cost breakdown, filtered to those
/// with actual activity.
struct PopoverDetailSources {
    let stats: PeriodStats

    var items: [(name: String, icon: String, source: SourceStats)] {
        [("CLI", "terminal", stats.cli), ("Commander", "app.connected.to.app.below.fill", stats.commander)]
            .filter { $0.source.total.cost > 0 || $0.source.total.linesAdded > 0 }
    }
}
