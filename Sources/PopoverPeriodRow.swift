import SwiftUI

/// One tappable row in the period cost table (Today/Week/Month).
struct PopoverPeriodRow: View {
    let label: String
    let stats: PeriodStats
    let onTap: () -> Void

    var body: some View {
        PopoverPeriodRowContent(label: label, stats: stats)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

#Preview {
    Grid {
        PopoverPeriodRow(label: "Today", stats: PeriodStats(cost: 4.5, linesAdded: 120, linesRemoved: 30), onTap: {})
    }
}
