import SwiftUI

public enum StatusBarPeriod: String, CaseIterable {
    case day, week, month

    public var label: String {
        switch self {
        case .day: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }

    public var prefix: String {
        switch self {
        case .day: return "D"
        case .week: return "W"
        case .month: return "M"
        }
    }
}

public enum AgentSortOrder: String, CaseIterable {
    case recentlyUpdated, cost, contextUsage

    public var label: String {
        switch self {
        case .recentlyUpdated: return "Recent"
        case .cost: return "Cost"
        case .contextUsage: return "Context"
        }
    }
}

public enum SubagentContextBudget: String, CaseIterable {
    case k200, m1

    public var label: String {
        switch self {
        case .k200: return "200K"
        case .m1:   return "1M"
        }
    }

    public var tokens: Int {
        switch self {
        case .k200: return 200_000
        case .m1:   return 1_000_000
        }
    }
}

@Observable
public final class AppSettings {
    public var statusBarPeriod: StatusBarPeriod {
        didSet { UserDefaults.standard.set(statusBarPeriod.rawValue, forKey: "ClaudeUsageBar.statusBarPeriod") }
    }

    public var agentSortOrder: AgentSortOrder {
        didSet { UserDefaults.standard.set(agentSortOrder.rawValue, forKey: "ClaudeUsageBar.agentSortOrder") }
    }

    public var subagentContextBudget: SubagentContextBudget {
        didSet { UserDefaults.standard.set(subagentContextBudget.rawValue, forKey: "ClaudeUsageBar.subagentContextBudget") }
    }

    public var maxVisibleSubagents: Int {
        didSet { UserDefaults.standard.set(maxVisibleSubagents, forKey: "ClaudeUsageBar.maxVisibleSubagents") }
    }

    public var isLoading: Bool = false

    public init() {
        let periodRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.statusBarPeriod") ?? ""
        statusBarPeriod = StatusBarPeriod(rawValue: periodRaw) ?? .day

        let sortRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.agentSortOrder") ?? ""
        agentSortOrder = AgentSortOrder(rawValue: sortRaw) ?? .recentlyUpdated

        let budgetRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.subagentContextBudget") ?? ""
        subagentContextBudget = SubagentContextBudget(rawValue: budgetRaw) ?? .m1

        let stored = UserDefaults.standard.integer(forKey: "ClaudeUsageBar.maxVisibleSubagents")
        maxVisibleSubagents = stored > 0 ? stored : 5
    }
}
