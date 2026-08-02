import SwiftUI

/// Account header with plan badge, optional rate-limit banner/bars, cost summary, and
/// token usage — the expanded account header shown for Pro/Max accounts. The caller is
/// responsible for pre-filtering `freshRateLimitEvent` to nil when the event is stale.
struct PopoverPlanUsageCard: View {
    let displayName: String
    let planLabel: String
    let agentCount: Int
    let freshRateLimitEvent: RateLimitEvent?
    let liveRateLimits: RateLimits?
    let periodStats: AccountPeriodStats?
    let statsCache: StatsCache?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PopoverPlanUsageCardHeader(displayName: displayName, planLabel: planLabel, agentCount: agentCount)
            PopoverPlanUsageCardRateLimitSection(freshRateLimitEvent: freshRateLimitEvent, liveRateLimits: liveRateLimits)
            PopoverPlanUsageCardStatsSection(periodStats: periodStats, statsCache: statsCache)
        }
        .padding(8)
        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange.opacity(0.15), lineWidth: 1))
    }
}

#Preview {
    PopoverPlanUsageCard(
        displayName: "Personal", planLabel: "Max 20x", agentCount: 2,
        freshRateLimitEvent: nil, liveRateLimits: nil, periodStats: AccountPeriodStats(), statsCache: nil
    )
}
