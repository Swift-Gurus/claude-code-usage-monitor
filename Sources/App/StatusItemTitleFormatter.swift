import ClaudeUsageBarLib
import Foundation

/// Formats the menu-bar status item's title from the current settings/usage/agent state.
struct StatusItemTitleFormatter {
    let settings: AppSettings
    let usageData: UsageData
    let agentTracker: AgentTracker

    var title: String {
        let period = settings.statusBarPeriod
        if let accountID = settings.statusBarAccountID, let rateLimitText = rateLimitTitle(accountID: accountID) {
            return rateLimitText
        }
        return "\(accountPrefix)\(period.prefix): \(periodStats.cost.asCostString)"
    }

    private var periodStats: PeriodStats {
        if let accountID = settings.statusBarAccountID, let accountStats = usageData.byAccount[accountID] {
            switch settings.statusBarPeriod {
            case .day: return accountStats.day
            case .week: return accountStats.week
            case .month: return accountStats.month
            }
        }
        switch settings.statusBarPeriod {
        case .day: return usageData.day
        case .week: return usageData.week
        case .month: return usageData.month
        }
    }

    private var accountPrefix: String {
        guard settings.accounts.count > 1,
              let accountID = settings.statusBarAccountID,
              let account = settings.accounts.first(where: { $0.id == accountID }) else {
            return ""
        }
        return "\(account.displayName) "
    }

    private func rateLimitTitle(accountID: UUID) -> String? {
        guard let rl = agentTracker.activeAgents
            .first(where: { $0.accountID == accountID && $0.rateLimits?.hasData == true })?.rateLimits,
            let fiveH = rl.fiveHour?.usedPercentage else {
            return nil
        }
        let weekPct = rl.sevenDay?.usedPercentage.map { String(format: " W:%.0f%%", $0) } ?? ""
        return "\(accountPrefix)5h:\(String(format: "%.0f", fiveH))%\(weekPct)"
    }
}
