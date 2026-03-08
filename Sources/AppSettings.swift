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
        let mode = DisplayMode(rawValue: displayRaw) ?? .popover
        displayMode = mode
        launchedDisplayMode = mode

        expandThinking = UserDefaults.standard.object(forKey: "ClaudeUsageBar.expandThinking") as? Bool ?? false
        expandTools = UserDefaults.standard.object(forKey: "ClaudeUsageBar.expandTools") as? Bool ?? false

        let appearanceRaw = UserDefaults.standard.string(forKey: "ClaudeUsageBar.appearanceMode") ?? ""
        appearanceMode = AppearanceMode(rawValue: appearanceRaw) ?? .system
    }
}
