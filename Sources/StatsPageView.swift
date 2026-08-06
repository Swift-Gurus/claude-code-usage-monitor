import SwiftUI

/**
 solid-name: StatsPageView
 solid-category: screen
 solid-stack: [swiftui]
 solid-description: Displays aggregated session usage statistics for a selectable time period.
 */
struct StatsPageView<DS: StatsPageState & StatsPageActions>: View {
    let data: UsageData
    let settings: AppSettings
    @State var dataSource: DS
    let onDismiss: () -> Void

    @State private var period: StatusBarPeriod

    init(data: UsageData, settings: AppSettings, dataSource: DS, initialPeriod: StatusBarPeriod, onDismiss: @escaping () -> Void) {
        self.data = data
        self.settings = settings
        _dataSource = State(initialValue: dataSource)
        self.onDismiss = onDismiss
        _period = State(initialValue: initialPeriod)
    }

    private var periodStats: PeriodStats {
        selectByPeriod(period, day: data.day, week: data.week, month: data.month)
    }

    private var sessionStats: SessionStats {
        selectByPeriod(period, day: dataSource.day, week: dataSource.week, month: dataSource.month)
    }

    var body: some View {
        SessionDetailScaffold(
            title: "\(period.label) Stats", settings: settings, openFileHelp: "", onDismiss: onDismiss, onOpenFile: nil
        ) {
            StatsPageContent(
                period: $period, periodStats: periodStats,
                sessionStats: sessionStats, isLoading: dataSource.isLoading
            )
        }
        .task { dataSource.reload() }
    }
}

#Preview {
    StatsPageView(
        data: UsageData(),
        settings: AppSettings(),
        dataSource: PreviewStatsPageDataSource(),
        initialPeriod: .day,
        onDismiss: {}
    )
}
