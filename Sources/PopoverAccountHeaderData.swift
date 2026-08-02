import Foundation

/// Resolves everything PopoverAccountHeader needs for one account group, from the
/// popover's top-level state (accounts, active agents, cost data, cached rate-limit
/// events, and stats caches).
public struct PopoverAccountHeaderData {
    let group: PopoverAccountGroup
    let accounts: [Account]
    let activeAgents: [AgentInfo]
    let byAccount: [UUID: AccountPeriodStats]
    let rateLimitEvents: [UUID: RateLimitEvent]
    let statsCaches: [UUID: StatsCache]

    private var identity: PopoverAccountIdentity {
        PopoverAccountIdentity(group: group, accounts: accounts)
    }

    private var rateLimitData: PopoverAccountRateLimitData {
        PopoverAccountRateLimitData(
            group: group, hasRateLimitPlan: identity.matchedAccount?.accountType.hasRateLimits == true,
            activeAgents: activeAgents, byAccount: byAccount,
            rateLimitEvents: rateLimitEvents, statsCaches: statsCaches
        )
    }

    var displayName: String { identity.displayName }
    var showPlanCard: Bool { rateLimitData.showPlanCard }
    var liveRateLimits: RateLimits? { rateLimitData.liveRateLimits }
    var rateLimitEvent: RateLimitEvent? { rateLimitData.rateLimitEvent }
    var periodStats: AccountPeriodStats? { rateLimitData.periodStats }
    var statsCache: StatsCache? { rateLimitData.statsCache }
}
