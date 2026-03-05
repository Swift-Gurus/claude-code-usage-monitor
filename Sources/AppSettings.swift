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

@Observable
public final class AppSettings {
    public var statusBarPeriod: StatusBarPeriod {
        didSet { UserDefaults.standard.set(statusBarPeriod.rawValue, forKey: "ClaudeUsageBar.statusBarPeriod") }
    }

    public var agentSortOrder: AgentSortOrder {
        didSet { UserDefaults.standard.set(agentSortOrder.rawValue, forKey: "ClaudeUsageBar.agentSortOrder") }
    }

    public init() {
        let periodRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.statusBarPeriod") ?? ""
        statusBarPeriod = StatusBarPeriod(rawValue: periodRaw) ?? .day

        let sortRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.agentSortOrder") ?? ""
        agentSortOrder = AgentSortOrder(rawValue: sortRaw) ?? .recentlyUpdated
    }
}
