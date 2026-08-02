/// Labels the three period stats for tabular display.
struct PopoverPeriodRows {
    let dayStats: PeriodStats
    let weekStats: PeriodStats
    let monthStats: PeriodStats

    var rows: [(label: String, stats: PeriodStats)] {
        [("Today", dayStats), ("Week", weekStats), ("Month", monthStats)]
    }
}
