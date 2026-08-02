import SwiftUI

/// Popover router branch for the Today/Week/Month cost breakdown detail screen.
struct PeriodDetailRoute: View {
    let label: String
    let statsResolver: PeriodStatsResolving
    let settings: AppSettings
    let navigation: PopoverNavigationState

    var body: some View {
        DetailScreenView(
            label: label, statsResolver: statsResolver,
            settings: settings, filterAccountID: Binding(get: { navigation.filterAccountID }, set: { navigation.filterAccountID = $0 }),
            onBack: navigation.dismissPeriod, onViewStatsPage: { navigation.viewStatsPage(for: label) }
        )
    }
}

#Preview {
    PeriodDetailRoute(
        label: "Today", statsResolver: PopoverPeriodStatsResolver(data: UsageData(), filterAccountID: nil),
        settings: AppSettings(), navigation: PopoverNavigationState()
    )
}
