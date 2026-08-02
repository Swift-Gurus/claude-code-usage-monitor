import SwiftUI

/// Popover navigation branch: the aggregated tool/token stats page.
struct StatsPageScreenView<DS: StatsPageState & StatsPageActions>: View {
    let data: UsageData
    let settings: AppSettings
    let dataSource: DS
    let period: StatusBarPeriod
    let onDismiss: () -> Void

    var body: some View {
        StatsPageView(data: data, settings: settings, dataSource: dataSource, initialPeriod: period, onDismiss: onDismiss)
    }
}

#Preview {
    StatsPageScreenView(
        data: UsageData(), settings: AppSettings(), dataSource: PreviewStatsPageDataSource(),
        period: .day, onDismiss: {}
    )
}
