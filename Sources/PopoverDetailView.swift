import SwiftUI

/// Period cost breakdown detail screen, reached by tapping a row in the period table.
struct PopoverDetailView: View {
    let label: String
    let stats: PeriodStats
    let settings: AppSettings
    @Binding var filterAccountID: UUID?
    let onBack: () -> Void
    let onViewStatsPage: () -> Void

    var body: some View {
        PopoverDetailContent(
            label: label, stats: stats, settings: settings, filterAccountID: $filterAccountID,
            onBack: onBack, onViewStatsPage: onViewStatsPage
        )
    }
}

#Preview {
    PopoverDetailView(
        label: "Today", stats: PeriodStats(cost: 12.34, linesAdded: 400, linesRemoved: 100),
        settings: AppSettings(), filterAccountID: .constant(nil), onBack: {}, onViewStatsPage: {}
    )
}
