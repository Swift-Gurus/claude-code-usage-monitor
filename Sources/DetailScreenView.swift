import SwiftUI

/// Popover navigation branch: the Today/Week/Month cost breakdown detail screen.
struct DetailScreenView: View {
    let label: String
    let statsResolver: PeriodStatsResolving
    let settings: AppSettings
    @Binding var filterAccountID: UUID?
    let onBack: () -> Void
    let onViewStatsPage: () -> Void

    var body: some View {
        PopoverScreenScroll(displayMode: settings.displayMode) {
            PopoverDetailView(
                label: label, stats: statsResolver.stats(for: label), settings: settings,
                filterAccountID: $filterAccountID, onBack: onBack, onViewStatsPage: onViewStatsPage
            )
        }
    }
}

#Preview {
    DetailScreenView(
        label: "Today", statsResolver: PopoverPeriodStatsResolver(data: UsageData(), filterAccountID: nil),
        settings: AppSettings(), filterAccountID: .constant(nil), onBack: {}, onViewStatsPage: {}
    )
}
