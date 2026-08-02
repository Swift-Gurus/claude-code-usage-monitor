import Foundation

/// Rolls a day-keyed stats map into day/week/month totals, comparing each bucket's own
/// yyyy-MM-dd key against the period boundaries.
struct DayBucketedStatsRollup {
    let statsByDay: [String: SessionStats]
    let boundaries: PeriodBoundaries

    var day: SessionStats { rolled(from: boundaries.today) }
    var week: SessionStats { rolled(from: boundaries.weekStart) }
    var month: SessionStats { rolled(from: boundaries.monthStart) }

    private func rolled(from start: Date) -> SessionStats {
        var total = SessionStats()
        for (dayString, stats) in statsByDay {
            guard let date = Self.dayParser.date(from: dayString), date >= start else { continue }
            total.merge(stats)
        }
        return total
    }

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
