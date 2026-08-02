import SwiftUI

/// Period picker + cost/lines summary + stats panel, shown inside StatsPageView's scaffold.
struct StatsPageContent: View {
    @Binding var period: StatusBarPeriod
    let periodStats: PeriodStats
    let sessionStats: SessionStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusBarPeriodPicker(period: $period)
            CostLinesSummaryView(stats: periodStats)
            Divider()
            StatsPanelView(stats: sessionStats)
        }
    }
}

#Preview {
    StatsPageContent(
        period: .constant(.day),
        periodStats: PeriodStats(cost: 12.34, linesAdded: 120, linesRemoved: 40),
        sessionStats: SessionStats(tools: ToolCallStats(countsByName: ["Bash": 3]))
    )
}
