import SwiftUI

/// Today/Week/Month cost table with tappable rows leading to the detail breakdown.
struct PopoverPeriodTable: View {
    let dayStats: PeriodStats
    let weekStats: PeriodStats
    let monthStats: PeriodStats
    let onSelect: (String) -> Void

    private var rows: [(label: String, stats: PeriodStats)] {
        PopoverPeriodRows(dayStats: dayStats, weekStats: weekStats, monthStats: monthStats).rows
    }

    var body: some View {
        Grid(alignment: .trailing, verticalSpacing: 8) {
            PopoverPeriodTableRows(rows: rows, onSelect: onSelect)
        }
    }
}

#Preview {
    PopoverPeriodTable(
        dayStats: PeriodStats(cost: 4.5, linesAdded: 120, linesRemoved: 30),
        weekStats: PeriodStats(cost: 20, linesAdded: 500, linesRemoved: 100),
        monthStats: PeriodStats(cost: 80, linesAdded: 2000, linesRemoved: 400),
        onSelect: { _ in }
    )
}
