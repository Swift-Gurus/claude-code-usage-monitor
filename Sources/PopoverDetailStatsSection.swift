import SwiftUI

/// Total row, Stats page entry button, and per-source breakdowns for a period.
struct PopoverDetailStatsSection: View {
    let stats: PeriodStats
    let onViewStatsPage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PopoverDetailTotalRow(cost: stats.cost)
            PopoverViewStatsPageButton(action: onViewStatsPage)
            PopoverSourceBreakdownsList(sources: PopoverDetailSources(stats: stats).items)
        }
    }
}

#Preview {
    PopoverDetailStatsSection(stats: PeriodStats(cost: 12.34, linesAdded: 400, linesRemoved: 100), onViewStatsPage: {})
}
