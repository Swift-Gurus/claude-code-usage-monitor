import SwiftUI

/// Popover router branch for the aggregated tool/token stats page.
struct StatsPageRoute<DS: StatsPageState & StatsPageActions>: View {
    let data: UsageData
    let settings: AppSettings
    let dataSource: DS
    let period: StatusBarPeriod
    let navigation: PopoverNavigationState

    var body: some View {
        StatsPageScreenView(
            data: data, settings: settings, dataSource: dataSource,
            period: period, onDismiss: navigation.dismissStatsPage
        )
    }
}

#Preview {
    StatsPageRoute(
        data: UsageData(), settings: AppSettings(), dataSource: PreviewStatsPageDataSource(),
        period: .day, navigation: PopoverNavigationState()
    )
}
