import SwiftUI

/// Picks the plan usage card (Pro/Max, or any account with live rate-limit data) or the
/// simple account header, for one account group in the popover's agent list. The
/// caller is responsible for pre-filtering `freshRateLimitEvent` to nil when stale.
struct PopoverAccountHeader: View {
    let group: PopoverAccountGroup
    let displayName: String
    let showPlanCard: Bool
    let freshRateLimitEvent: RateLimitEvent?
    let liveRateLimits: RateLimits?
    let periodStats: AccountPeriodStats?
    let statsCache: StatsCache?

    var body: some View {
        if showPlanCard {
            PopoverPlanUsageCard(
                displayName: displayName, planLabel: group.accountType.label, agentCount: group.totalCount,
                freshRateLimitEvent: freshRateLimitEvent, liveRateLimits: liveRateLimits,
                periodStats: periodStats, statsCache: statsCache
            )
        } else {
            PopoverSimpleAccountHeader(displayName: displayName, accountTypeLabel: group.accountType.label, totalCount: group.totalCount)
        }
    }
}

#Preview {
    PopoverAccountHeader(
        group: PopoverAccountGroup(accountID: UUID(), accountName: "Personal", accountType: .maxPlan20, active: [], idle: []),
        displayName: "Personal", showPlanCard: true, freshRateLimitEvent: nil, liveRateLimits: nil,
        periodStats: nil, statsCache: nil
    )
}
