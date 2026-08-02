import SwiftUI

/// Monthly messages/tokens/sessions summary plus a per-model breakdown, from the
/// account's cached usage stats.
struct PopoverPlanUsageTokens: View {
    let stats: StatsCache

    private var display: PopoverPlanUsageTokensDisplay {
        PopoverPlanUsageTokensDisplay(stats: stats)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            dividerLine
            headerText
            statsRow
            modelUsageSection
        }
    }

    private var dividerLine: some View {
        Divider().padding(.vertical, 2)
    }

    private var headerText: some View {
        Text("Usage Stats").font(.system(size: 9)).foregroundStyle(.tertiary)
    }

    private var statsRow: some View {
        PopoverPlanUsageStatsRow(
            avgMessagesPerDay: display.avgMessagesPerDay,
            outputTokens: display.totalOutputTokens,
            totalSessions: display.totalSessions
        )
    }

    private var modelUsageSection: some View {
        PopoverModelUsageSection(sortedModelUsage: display.sortedModelUsage)
    }
}

#Preview {
    PopoverPlanUsageTokens(stats: StatsCache(
        dailyActivity: [], dailyModelTokens: [], modelUsage: [], totalSessions: 8, totalMessages: 120
    ))
}
