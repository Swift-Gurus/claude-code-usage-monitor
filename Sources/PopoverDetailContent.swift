import SwiftUI

/// Full content layout for the period breakdown detail screen.
struct PopoverDetailContent: View {
    let label: String
    let stats: PeriodStats
    let settings: AppSettings
    @Binding var filterAccountID: UUID?
    let onBack: () -> Void
    let onViewStatsPage: () -> Void

    private var navFont: Font { settings.displayMode == .window ? .body : .caption }
    private var titleFont: Font { settings.displayMode == .window ? .title3 : .headline }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PopoverDetailHeader(label: label, navFont: navFont, titleFont: titleFont, onBack: onBack)
            Divider()
            accountFilterIfNeeded
            PopoverDetailStatsSection(stats: stats, onViewStatsPage: onViewStatsPage)
        }
    }

    @ViewBuilder
    private var accountFilterIfNeeded: some View {
        if settings.accounts.count > 1 {
            PopoverAccountFilterDropdown(accounts: settings.accounts, filterAccountID: $filterAccountID)
        }
    }
}

#Preview {
    PopoverDetailContent(
        label: "Today", stats: PeriodStats(cost: 12.34, linesAdded: 400, linesRemoved: 100),
        settings: AppSettings(), filterAccountID: .constant(nil), onBack: {}, onViewStatsPage: {}
    )
}
