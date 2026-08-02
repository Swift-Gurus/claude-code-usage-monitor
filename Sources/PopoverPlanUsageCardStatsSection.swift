import SwiftUI

/// Cost summary (if period stats are available) plus token usage breakdown (if the
/// account's stats cache is available).
struct PopoverPlanUsageCardStatsSection: View {
    let periodStats: AccountPeriodStats?
    let statsCache: StatsCache?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            costSummaryIfNeeded
            tokensIfNeeded
        }
    }

    @ViewBuilder
    private var costSummaryIfNeeded: some View {
        if let periodStats {
            PopoverAccountCostSummary(stats: periodStats)
        }
    }

    @ViewBuilder
    private var tokensIfNeeded: some View {
        if let statsCache {
            PopoverPlanUsageTokens(stats: statsCache)
        }
    }
}

#Preview {
    PopoverPlanUsageCardStatsSection(periodStats: nil, statsCache: nil)
}
