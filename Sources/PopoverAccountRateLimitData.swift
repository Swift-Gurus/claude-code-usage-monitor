import Foundation

/// Resolves live rate-limit data, cached rate-limit events, and cost/stats caches for
/// one account group.
struct PopoverAccountRateLimitData {
    let group: PopoverAccountGroup
    let hasRateLimitPlan: Bool
    let activeAgents: [AgentInfo]
    let byAccount: [UUID: AccountPeriodStats]
    let rateLimitEvents: [UUID: RateLimitEvent]
    let statsCaches: [UUID: StatsCache]

    private var accountsWithLiveRateLimits: [AgentInfo] {
        activeAgents
            .filter { $0.accountID == group.accountID && $0.rateLimits?.hasData == true }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var showPlanCard: Bool {
        hasRateLimitPlan || !accountsWithLiveRateLimits.isEmpty
    }

    var liveRateLimits: RateLimits? {
        accountsWithLiveRateLimits.first?.rateLimits
    }

    var rateLimitEvent: RateLimitEvent? { rateLimitEvents[group.accountID] }
    var periodStats: AccountPeriodStats? { byAccount[group.accountID] }
    var statsCache: StatsCache? { statsCaches[group.accountID] }
}
