import Foundation

/// Today/week-start/month-start boundaries for period rollups, matching UsageData's
/// Monday-start week convention.
struct PeriodBoundaries {
    let today: Date
    let weekStart: Date
    let monthStart: Date

    init(now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7
        self.today = today
        self.weekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        self.monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? today
    }
}
