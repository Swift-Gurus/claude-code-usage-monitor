import SwiftUI

public enum AccountType: String, Codable, CaseIterable, Sendable {
    case enterprise  // API / org account — pay per token, no rolling limits
    case proPlan     // $20/mo subscription — shared rolling window limits
    case maxPlan5    // Max $100/mo — higher rolling window limits
    case maxPlan20   // Max $200/mo — highest rolling window limits

    public var label: String {
        switch self {
        case .enterprise: return "Enterprise"
        case .proPlan: return "Pro"
        case .maxPlan5: return "Max 5x"
        case .maxPlan20: return "Max 20x"
        }
    }

    /// Whether this is a consumer plan with rolling window rate limits.
    public var hasRateLimits: Bool { self != .enterprise }
}

public struct Account: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var alias: String  // short display label, can include emoji e.g. "🏢 Work" or "🏠 Personal"
    public var claudeDir: String  // e.g. "/Users/crowea/.claude"
    public var accountType: AccountType

    /// Display label: alias if set, otherwise name.
    public var displayName: String { alias.isEmpty ? name : alias }

    public var usageDir: URL { URL(fileURLWithPath: claudeDir).appendingPathComponent("usage") }
    public var commanderDir: URL { usageDir.appendingPathComponent("commander") }
    public var projectsDir: URL { URL(fileURLWithPath: claudeDir).appendingPathComponent("projects") }

    public init(id: UUID = UUID(), name: String, alias: String = "", claudeDir: String, accountType: AccountType = .enterprise) {
        self.id = id
        self.name = name
        self.alias = alias
        self.claudeDir = claudeDir
        self.accountType = accountType
    }

    public static var `default`: Account {
        Account(
            name: "Default",
            claudeDir: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude").path
        )
    }
}

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

public enum DisplayMode: String, CaseIterable {
    case popover, window

    public var label: String {
        switch self {
        case .popover: return "Popover"
        case .window: return "Window"
        }
    }
}

public enum AppearanceMode: String, CaseIterable {
    case system, dark, light

    public var label: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

public enum SubagentSortOrder: String, CaseIterable {
    case recent, cost, context, name

    public var label: String {
        switch self {
        case .recent: return "Recent"
        case .cost: return "Cost"
        case .context: return "Context"
        case .name: return "Name"
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

    public var maxVisibleAgents: Int {
        didSet { UserDefaults.standard.set(maxVisibleAgents, forKey: "ClaudeUsageBar.maxVisibleAgents") }
    }

    public var maxVisibleSubagents: Int {
        didSet { UserDefaults.standard.set(maxVisibleSubagents, forKey: "ClaudeUsageBar.maxVisibleSubagents") }
    }

    public var maxVisibleLogMessages: Int {
        didSet { UserDefaults.standard.set(maxVisibleLogMessages, forKey: "ClaudeUsageBar.maxVisibleLogMessages") }
    }

    public var subagentSortOrder: SubagentSortOrder {
        didSet { UserDefaults.standard.set(subagentSortOrder.rawValue, forKey: "ClaudeUsageBar.subagentSortOrder") }
    }

    /// The mode the app actually launched with (set once at init, never changes).
    public let launchedDisplayMode: DisplayMode

    public var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "ClaudeUsageBar.displayMode") }
    }

    /// True when the user has changed display mode but hasn't restarted yet.
    public var displayModeChanged: Bool { displayMode != launchedDisplayMode }

    public static func relaunch() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", url.path]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    public var expandThinking: Bool {
        didSet { UserDefaults.standard.set(expandThinking, forKey: "ClaudeUsageBar.expandThinking") }
    }

    public var expandTools: Bool {
        didSet { UserDefaults.standard.set(expandTools, forKey: "ClaudeUsageBar.expandTools") }
    }

    public var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "ClaudeUsageBar.appearanceMode") }
    }

    public var accounts: [Account] {
        didSet {
            if let data = try? JSONEncoder().encode(accounts) {
                UserDefaults.standard.set(data, forKey: "ClaudeUsageBar.accounts")
            }
        }
    }

    /// Which account to show in status bar. nil = combined (all accounts).
    public var statusBarAccountID: UUID? {
        didSet {
            if let id = statusBarAccountID {
                UserDefaults.standard.set(id.uuidString, forKey: "ClaudeUsageBar.statusBarAccountID")
            } else {
                UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.statusBarAccountID")
            }
        }
    }

    public var isLoading: Bool = false

    public init() {
        let periodRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.statusBarPeriod") ?? ""
        statusBarPeriod = StatusBarPeriod(rawValue: periodRaw) ?? .day

        let sortRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.agentSortOrder") ?? ""
        agentSortOrder = AgentSortOrder(rawValue: sortRaw) ?? .recentlyUpdated

        let budgetRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.subagentContextBudget") ?? ""
        subagentContextBudget = SubagentContextBudget(rawValue: budgetRaw) ?? .m1

        let agentStored = UserDefaults.standard.integer(forKey: "ClaudeUsageBar.maxVisibleAgents")
        maxVisibleAgents = agentStored > 0 ? agentStored : 3

        let stored = UserDefaults.standard.integer(forKey: "ClaudeUsageBar.maxVisibleSubagents")
        maxVisibleSubagents = stored > 0 ? stored : 5

        let logStored = UserDefaults.standard.integer(forKey: "ClaudeUsageBar.maxVisibleLogMessages")
        maxVisibleLogMessages = logStored > 0 ? logStored : 8

        let subSortRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.subagentSortOrder") ?? ""
        subagentSortOrder = SubagentSortOrder(rawValue: subSortRaw) ?? .cost

        let displayRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.displayMode") ?? ""
        let mode = DisplayMode.window
        displayMode = mode
        launchedDisplayMode = mode

        expandThinking = UserDefaults.standard.object(forKey: "ClaudeUsageBar.expandThinking") as? Bool ?? false
        expandTools = UserDefaults.standard.object(forKey: "ClaudeUsageBar.expandTools") as? Bool ?? false

        let appearanceRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.appearanceMode") ?? ""
        appearanceMode = AppearanceMode(rawValue: appearanceRaw) ?? .system

        if let accountIDStr = UserDefaults.standard.string(forKey: "ClaudeUsageBar.statusBarAccountID"),
           let uuid = UUID(uuidString: accountIDStr) {
            statusBarAccountID = uuid
        } else {
            statusBarAccountID = nil
        }

        if let accountData = UserDefaults.standard.data(forKey: "ClaudeUsageBar.accounts"),
           let decoded = try? JSONDecoder().decode([Account].self, from: accountData),
           !decoded.isEmpty {
            accounts = decoded
        } else {
            accounts = [.default]
        }
    }
}
