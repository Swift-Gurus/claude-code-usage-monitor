import SwiftUI

/// Collects each agent row's actual rendered height for precise viewport sizing.
private struct AgentRowHeightsKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

public struct PopoverView: View {
    public var data: UsageData
    public var agentTracker: AgentTracker
    public var settings: AppSettings
    public var sessionManager: SessionManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var installed = StatuslineInstaller.isInstalled
    @State private var installError = false
    @State private var selectedPeriod: String?
    @State private var showSettings = false
    @State private var selectedAgent: AgentInfo?
    @State private var agentRowHeights: [Int: CGFloat] = [:]
    @State private var rateLimitEvents: [UUID: RateLimitEvent] = [:]
    @State private var statsCaches: [UUID: StatsCache] = [:]
    @State private var filterAccountID: UUID?  // nil = all accounts

    // Colors that adapt to dark/light mode
    private var idleColor: Color { colorScheme == .dark ? Color(white: 0.7) : .gray }
    private var idleOpacity: Double { colorScheme == .dark ? 0.85 : 0.6 }
    private var addedColor: Color { colorScheme == .dark ? .green : Color(red: 0.1, green: 0.55, blue: 0.1) }
    private var removedColor: Color { colorScheme == .dark ? Color(red: 1.0, green: 0.4, blue: 0.4) : .red }

    public init(data: UsageData, agentTracker: AgentTracker, settings: AppSettings, sessionManager: SessionManager) {
        self.data = data
        self.agentTracker = agentTracker
        self.settings = settings
        self.sessionManager = sessionManager
    }

    private func statsFor(_ label: String) -> PeriodStats {
        if let accountID = filterAccountID,
           let acct = data.byAccount[accountID] {
            switch label {
            case "Today": return acct.day
            case "Week": return acct.week
            case "Month": return acct.month
            default: return acct.day
            }
        }
        switch label {
        case "Today": return data.day
        case "Week": return data.week
        case "Month": return data.month
        default: return data.day
        }
    }

    public var body: some View {
        content
            .preferredColorScheme(settings.appearanceMode.colorScheme)
    }

    @ViewBuilder
    private var content: some View {
        if showSettings {
            if settings.displayMode == .window {
                ScrollView {
                    SettingsView(settings: settings) { showSettings = false }
                        .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SettingsView(settings: settings) { showSettings = false }
                    .padding(16)
            }
        } else if let agent = selectedAgent {
            // Use live data from AgentTracker if available, fall back to initial synthetic AgentInfo
            let liveAgent = agentTracker.activeAgents.first(where: { $0.pid == agent.pid }) ?? agent
            SubagentDetailView(agent: liveAgent, agentTracker: agentTracker, settings: settings, sessionManager: sessionManager) { selectedAgent = nil }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let label = selectedPeriod {
            if settings.displayMode == .window {
                ScrollView {
                    detailView(label: label, stats: statsFor(label))
                        .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                detailView(label: label, stats: statsFor(label))
                    .padding(16)
            }
        } else {
            if settings.displayMode == .window {
                ScrollView {
                    mainView
                        .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainView
                    .padding(16)
            }
        }
    }

    // MARK: - Main View

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Account filter
            if settings.accounts.count > 1 {
                accountFilterDropdown
            }

            periodTable

            Divider()

            if !workingAgents.isEmpty || !idleAgents.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: agentRowSpacing) {
                        ForEach(Array(allAgentsFlat.enumerated()), id: \.element.id) { idx, item in
                            Group {
                                switch item {
                                case .divider:
                                    Divider().padding(.vertical, 4)
                                case .header(let group):
                                    accountHeader(group)
                                case .agent(let agent):
                                    agentRow(agent)
                                        .padding(.leading, 8)
                                }
                            }
                            .background(GeometryReader { geo in
                                Color.clear.preference(
                                    key: AgentRowHeightsKey.self,
                                    value: [idx: geo.size.height]
                                )
                            })
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(height: agentViewportHeight)
                .onPreferenceChange(AgentRowHeightsKey.self) { heights in
                    agentRowHeights = heights
                }
            } else if settings.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).scaleEffect(0.8)
                    Text("Loading active agents...")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                Text("No active agents")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }

            Divider()

            Button {
                openProject()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Open Project")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Divider()

            ForEach(settings.accounts) { account in
                let acctInstalled = StatuslineInstaller.isInstalled(claudeDir: account.claudeDir)
                HStack(spacing: 6) {
                    Image(systemName: acctInstalled
                          ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(acctInstalled ? .green : .red)
                    Text(acctInstalled
                         ? "\(account.displayName) statusline active"
                         : "\(account.displayName) statusline not configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !acctInstalled {
                        Spacer()
                        Button("Install") {
                            let success = StatuslineInstaller.install(claudeDir: account.claudeDir)
                            installed = settings.accounts.allSatisfy {
                                StatuslineInstaller.isInstalled(claudeDir: $0.claudeDir)
                            }
                            installError = !success
                        }
                        .font(.caption)
                    }
                }
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .task {
            await loadPlanData()
        }
    }

    private func loadPlanData() async {
        let accounts = settings.accounts
        let results = await Task.detached(priority: .utility) {
            var events: [UUID: RateLimitEvent] = [:]
            var caches: [UUID: StatsCache] = [:]
            for account in accounts {
                if let event = RateLimitScanner.lastRateLimitEvent(claudeDir: account.claudeDir) {
                    events[account.id] = event
                }
                if let stats = StatsCache.load(claudeDir: account.claudeDir) {
                    caches[account.id] = stats
                }
            }
            return (events, caches)
        }.value
        rateLimitEvents = results.0
        statsCaches = results.1
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a project directory to open with Claude"
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bridge = sessionManager.spawn(workingDir: url.path) else { return }

        // Navigate immediately — construct minimal AgentInfo from what we know
        selectedAgent = AgentInfo(
            pid: bridge.childPID, model: "Starting...", agentName: "",
            contextPercent: 0, contextWindow: 0, cost: 0,
            linesAdded: 0, linesRemoved: 0,
            workingDir: url.path, sessionID: "",
            durationMs: 0, apiDurationMs: 0,
            updatedAt: Date().timeIntervalSince1970, cpuUsage: 0,
            isIdle: false, source: .cli
        )
    }

    private let agentRowSpacing: CGFloat = 6

    /// Sum of enough flat items (headers + agents) to show maxVisibleAgents agent cards.
    private var agentViewportHeight: CGFloat? {
        if settings.displayMode == .window { return nil }
        let items = allAgentsFlat
        guard !items.isEmpty else { return nil }

        // Count flat items needed to show N agent cards (headers don't count toward the limit)
        var agentsSeen = 0
        var n = 0
        for item in items {
            n += 1
            if case .agent = item { agentsSeen += 1 }
            if agentsSeen >= settings.maxVisibleAgents { break }
        }

        guard agentRowHeights.count >= n else { return nil }
        let h = (0..<n).compactMap { agentRowHeights[$0] }.reduce(0, +)
        return h + agentRowSpacing * CGFloat(max(0, n - 1))
    }

    // MARK: - Agents

    private func sortAgents(_ agents: [AgentInfo]) -> [AgentInfo] {
        switch settings.agentSortOrder {
        case .recentlyUpdated: return agents.sorted { $0.updatedAt > $1.updatedAt }
        case .cost: return agents.sorted { $0.cost > $1.cost }
        case .contextUsage: return agents.sorted { $0.contextPercent > $1.contextPercent }
        }
    }

    private var workingAgents: [AgentInfo] {
        sortAgents(agentTracker.activeAgents.filter { !$0.isIdle })
    }

    private var idleAgents: [AgentInfo] {
        sortAgents(agentTracker.activeAgents.filter(\.isIdle))
    }

    private struct AccountGroup {
        let accountID: UUID
        let accountName: String
        let accountType: AccountType
        let active: [AgentInfo]
        let idle: [AgentInfo]

        var totalCount: Int { active.count + idle.count }
    }

    private var groupedAccounts: [AccountGroup] {
        // Group agents by account; use settings.accounts order for stable ordering
        var result: [AccountGroup] = []
        for account in settings.accounts {
            let active = workingAgents.filter { $0.accountID == account.id }
            let idle = idleAgents.filter { $0.accountID == account.id }
            guard !active.isEmpty || !idle.isEmpty else { continue }
            result.append(AccountGroup(
                accountID: account.id,
                accountName: account.displayName,
                accountType: account.accountType,
                active: active,
                idle: idle
            ))
        }
        // Catch any agents whose accountID doesn't match a known account (e.g. default)
        let knownIDs = Set(settings.accounts.map(\.id))
        let unknownActive = workingAgents.filter { !knownIDs.contains($0.accountID) }
        let unknownIdle = idleAgents.filter { !knownIDs.contains($0.accountID) }
        if !unknownActive.isEmpty || !unknownIdle.isEmpty {
            result.append(AccountGroup(
                accountID: UUID(),
                accountName: "Claude",
                accountType: .enterprise,
                active: unknownActive,
                idle: unknownIdle
            ))
        }
        return result
    }

    private enum AgentListItem: Identifiable {
        case divider(String)
        case header(AccountGroup)
        case agent(AgentInfo)

        var id: String {
            switch self {
            case .divider(let key): return "div-\(key)"
            case .header(let g): return "header-\(g.accountID.uuidString)"
            case .agent(let a): return "agent-\(a.pid)"
            }
        }
    }

    /// Flat list of dividers + headers + agents for indexed measurement.
    private var allAgentsFlat: [AgentListItem] {
        var items: [AgentListItem] = []
        for (i, group) in groupedAccounts.enumerated() {
            if i > 0 { items.append(.divider(group.accountID.uuidString)) }
            items.append(.header(group))
            for agent in group.active { items.append(.agent(agent)) }
            for agent in group.idle { items.append(.agent(agent)) }
        }
        return items
    }

    /// Resolve display name for an account group — use alias if available.
    private func displayName(for group: AccountGroup) -> String {
        settings.accounts.first(where: { $0.id == group.accountID })?.displayName ?? group.accountName
    }

    @ViewBuilder
    private func accountHeader(_ group: AccountGroup) -> some View {
        let account = settings.accounts.first(where: { $0.id == group.accountID })
        let showPlanCard = (account?.accountType.hasRateLimits == true) || accountHasLiveRateLimitsForGroup(group)

        if showPlanCard, let account {
            planUsageCard(account: account, agentCount: group.totalCount)
        } else {
            simpleAccountHeader(group)
        }
    }

    private func simpleAccountHeader(_ group: AccountGroup) -> some View {
        HStack {
            Image(systemName: "person.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(displayName(for: group))
                .font(.subheadline)
                .fontWeight(.medium)
            Text(group.accountType.label)
                .font(.system(size: 9))
                .foregroundStyle(.blue)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            Spacer()
            Text("\(group.totalCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.blue.opacity(0.1), lineWidth: 1)
        )
    }

    private func accountHasLiveRateLimitsForGroup(_ group: AccountGroup) -> Bool {
        agentTracker.activeAgents.contains { $0.accountID == group.accountID && $0.rateLimits?.hasData == true }
    }

    private func agentRow(_ agent: AgentInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: name + cost
            HStack {
                Image(systemName: agent.isIdle ? "moon.zzz.fill" : "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(agent.isIdle ? idleColor : .green)
                Text(agent.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                if agent.isIdle {
                    Text(agent.idleText)
                        .font(.caption2)
                        .foregroundStyle(idleColor)
                }
                Text(String(format: "$%.2f", agent.cost))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            // Row 2: context bar + duration
            HStack(spacing: 8) {
                contextBar(agent.contextPercent, contextWindow: agent.contextWindow)
                Label(agent.durationText, systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Row 3: folder + source badge + lines
            HStack {
                Label(agent.shortDir, systemImage: "folder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if agent.source == .commander {
                    Text("Commander")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("+\(agent.linesAdded.formatted(.number.notation(.compactName)))")
                        .foregroundStyle(addedColor)
                    Text("-\(agent.linesRemoved.formatted(.number.notation(.compactName)))")
                        .foregroundStyle(removedColor)
                }
                    .font(.caption2)
            }

        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .opacity(agent.isIdle ? idleOpacity : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { selectedAgent = agent }
    }

    private func contextBar(_ pct: Int, contextWindow: Int = 0) -> some View {
        let color: Color = pct >= 90 ? .red : pct >= 70 ? .yellow : .green
        let millions = Double(contextWindow) / 1_000_000.0
        let windowLabel = contextWindow <= 0 ? ""
            : millions == Double(Int(millions)) ? "\(Int(millions))M"
            : String(format: "%.1fM", millions)
        return HStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(pct, 100)) / 100)
                }
            }
            .frame(width: 60, height: 6)
            Text(windowLabel.isEmpty ? "\(pct)%" : "\(pct)% · \(windowLabel)")
                .font(.caption2)
                .foregroundStyle(color)
        }
    }

    // MARK: - Period Stats Table

    private var hasMultipleAccounts: Bool {
        settings.accounts.count > 1
    }

    private func accountStats(for accountID: UUID, period: String) -> PeriodStats {
        guard let acct = data.byAccount[accountID] else { return PeriodStats() }
        switch period {
        case "Today": return acct.day
        case "Week": return acct.week
        case "Month": return acct.month
        default: return acct.day
        }
    }

    private var accountFilterDropdown: some View {
        Picker("Account", selection: Binding(
            get: { filterAccountID?.uuidString ?? "all" },
            set: { filterAccountID = $0 == "all" ? nil : UUID(uuidString: $0) }
        )) {
            Text("All Accounts").tag("all")
            ForEach(settings.accounts) { account in
                Text(account.displayName).tag(account.id.uuidString)
            }
        }
        .labelsHidden()
        .font(.caption)
    }

    private var periodTable: some View {
        let rows: [(String, PeriodStats)] = [
            ("Today", statsFor("Today")),
            ("Week", statsFor("Week")),
            ("Month", statsFor("Month"))
        ]

        return Grid(alignment: .trailing, verticalSpacing: 8) {
            GridRow {
                Spacer()
                    .gridColumnAlignment(.leading)
                Text("Cost")
                Text("+Lines")
                Text("-Lines")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            ForEach(rows, id: \.0) { label, stats in
                GridRow {
                    HStack(spacing: 4) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "$%.2f", stats.cost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Text("+\(stats.linesAdded.formatted(.number.notation(.compactName)))")
                        .font(.caption)
                        .foregroundStyle(addedColor)
                    Text("-\(stats.linesRemoved.formatted(.number.notation(.compactName)))")
                        .font(.caption)
                        .foregroundStyle(removedColor)
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedPeriod = label }

            }
        }
    }

    // MARK: - Plan Usage Card

    /// Check if any active agent for this account has live rate limit data.
    private func accountHasLiveRateLimits(_ account: Account) -> Bool {
        agentTracker.activeAgents.contains { $0.accountID == account.id && $0.rateLimits?.hasData == true }
    }

    /// Get the most recent rate limits from active agents for this account.
    private func liveRateLimits(for account: Account) -> RateLimits? {
        agentTracker.activeAgents
            .filter { $0.accountID == account.id && $0.rateLimits?.hasData == true }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first?.rateLimits
    }

    private func planUsageCard(account: Account, agentCount: Int = 0) -> some View {
        let acctStats = data.byAccount[account.id]
        let rateLimitEvent = rateLimitEvents[account.id]
        let statsCache = statsCaches[account.id]
        let live = liveRateLimits(for: account)

        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                // Rate limit warning
                let rateLimitExpired: Bool = {
                    guard let event = rateLimitEvent else { return true }
                    if let resetsAt = event.resetsAt, resetsAt > 0 {
                        return Date().timeIntervalSince1970 > resetsAt
                    }
                    return Date().timeIntervalSince(event.timestamp) > 18000
                }()
                if let event = rateLimitEvent, !rateLimitExpired {
                    rateLimitBanner(event: event, resetsAt: event.resetsAt)
                }

                // Account header row (matches simpleAccountHeader style)
                HStack {
                    Image(systemName: "person.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(account.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    let planLabel = account.accountType.hasRateLimits ? account.accountType.label : "Pro/Max"
                    Text(planLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                    Spacer()
                    if agentCount > 0 {
                        Text("\(agentCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Live rate limit bars (from statusline)
                if let rl = live {
                    rateLimitBars(rl)
                }

                // Usage stats: today / week / cost
                let dayCost = acctStats?.day.cost ?? 0
                let weekCost = acctStats?.week.cost ?? 0
                let monthCost = acctStats?.month.cost ?? 0

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Today").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Text(String(format: "$%.2f", dayCost))
                            .font(.caption2).fontWeight(.medium).foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("This Week").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Text(String(format: "$%.2f", weekCost))
                            .font(.caption2).fontWeight(.medium).foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("This Month").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Text(String(format: "$%.2f", monthCost))
                            .font(.caption2).fontWeight(.medium).foregroundStyle(.orange)
                    }
                    Spacer()
                }

                // Token usage from stats-cache
                if let stats = statsCache {
                    planUsageTokens(stats: stats)
                }
            }
            .padding(8)
            .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
            )
        )
    }

    private func rateLimitBars(_ rl: RateLimits) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let fiveH = rl.fiveHour, let pct = fiveH.usedPercentage {
                rateLimitRow(label: "5h window", pct: pct, resetsIn: fiveH.resetsInText)
            }
            if let sevenD = rl.sevenDay, let pct = sevenD.usedPercentage {
                rateLimitRow(label: "Weekly", pct: pct, resetsIn: sevenD.resetsInText)
            }
        }
    }

    private func rateLimitRow(label: String, pct: Double, resetsIn: String?) -> some View {
        let color: Color = pct >= 90 ? .red : pct >= 70 ? .yellow : .blue
        return HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: geo.size.width * CGFloat(min(pct, 100)) / 100)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.0f%%", pct))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .frame(width: 32, alignment: .trailing)
            if let resets = resetsIn {
                Text("resets \(resets)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short  // e.g. "12:48 PM"
        return f
    }()

    private func rateLimitBanner(event: RateLimitEvent, resetsAt: Double? = nil) -> some View {
        let now = Date()
        let elapsed = now.timeIntervalSince(event.timestamp)
        let isRecent = elapsed < 3600
        let hitTime = Self.timeFormatter.string(from: event.timestamp)

        // Compute reset countdown
        let resetText: String? = {
            if let resetsAt, resetsAt > 0 {
                let remaining = resetsAt - now.timeIntervalSince1970
                if remaining > 0 { return "Resets in \(formatDuration(remaining))" }
                return nil
            }
            let remaining = 18000 - elapsed
            if remaining > 0 { return "Resets in ~\(formatDuration(remaining))" }
            return nil
        }()

        return HStack(spacing: 6) {
            Image(systemName: isRecent ? "exclamationmark.octagon.fill" : "clock.badge.exclamationmark")
                .foregroundStyle(isRecent ? .red : .orange)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text("Rate limit hit at \(hitTime)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isRecent ? .red : .orange)
                if let resetText {
                    Text(resetText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isRecent ? Color.red : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 2
        return f
    }()

    private func formatDuration(_ seconds: Double) -> String {
        Self.durationFormatter.string(from: seconds) ?? "\(Int(seconds / 60))m"
    }

    private func planUsageTokens(stats: StatsCache) -> some View {
        let avgMsgs = stats.monthlyAvgMessages()
        let monthlyTokens = stats.monthlyDailyTokens()
        let monthOutputTokens = monthlyTokens.values.reduce(0, +)

        return VStack(alignment: .leading, spacing: 4) {
            Divider().padding(.vertical, 2)
            Text("Usage Stats")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Messages").font(.system(size: 9)).foregroundStyle(.tertiary)
                    Text(String(format: "%.0f/day", avgMsgs))
                        .font(.caption2).fontWeight(.medium)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Output Tokens").font(.system(size: 9)).foregroundStyle(.tertiary)
                    Text(formatTokens(monthOutputTokens))
                        .font(.caption2).fontWeight(.medium)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sessions").font(.system(size: 9)).foregroundStyle(.tertiary)
                    Text("\(stats.totalSessions)")
                        .font(.caption2).fontWeight(.medium)
                }
                Spacer()
            }

            // Per-model breakdown
            if !stats.modelUsage.isEmpty {
                let sorted = stats.modelUsage.sorted { $0.outputTokens > $1.outputTokens }
                ForEach(sorted, id: \.modelID) { model in
                    HStack(spacing: 4) {
                        Text(ClaudeModel.displayName(for: model.modelID))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("in: \(formatTokens(model.inputTokens + model.cacheReadInputTokens))")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text("out: \(formatTokens(model.outputTokens))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000_000 { return String(format: "%.1fB", Double(count) / 1_000_000_000) }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    // MARK: - Detail View

    private func detailView(label: String, stats: PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with back button
            HStack {
                Button {
                    selectedPeriod = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(settings.displayMode == .window ? .body : .caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                Text("\(label) Breakdown")
                    .font(settings.displayMode == .window ? .title3 : .headline)
            }

            Divider()

            // Account filter
            if settings.accounts.count > 1 {
                accountFilterDropdown
            }

            // Summary row
            HStack {
                Text("Total")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "$%.2f", stats.cost))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            // Source breakdowns
            let sources: [(String, String, SourceStats)] = [
                ("CLI", "terminal", stats.cli),
                ("Commander", "app.connected.to.app.below.fill", stats.commander)
            ]

            ForEach(sources.filter { $0.2.total.cost > 0 || $0.2.total.linesAdded > 0 }, id: \.0) { name, icon, source in
                Divider()
                sourceBreakdown(name: name, icon: icon, source: source)
            }
        }
    }

    private func costCell(_ cost: Double, font: Font = .caption, weight: Font.Weight = .medium) -> some View {
        Text(String(format: "$%.2f", cost))
            .font(font).fontWeight(weight)
            .foregroundStyle(.orange)
            .frame(width: 64, alignment: .trailing)
    }

    private func addedCell(_ count: Int, font: Font = .caption2) -> some View {
        Text("+\(count.formatted(.number.notation(.compactName)))")
            .font(font).foregroundStyle(addedColor)
            .frame(width: 46, alignment: .trailing)
    }

    private func removedCell(_ count: Int, font: Font = .caption2) -> some View {
        Text("-\(count.formatted(.number.notation(.compactName)))")
            .font(font).foregroundStyle(removedColor)
            .frame(width: 40, alignment: .trailing)
    }

    private func linesCell(added: Int, removed: Int, font: Font = .caption2) -> some View {
        HStack(spacing: 0) {
            addedCell(added, font: font)
            removedCell(removed, font: font)
        }
    }


    private func sourceBreakdown(name: String, icon: String, source: SourceStats) -> some View {
        let models = source.byModel.sorted { $0.value.cost > $1.value.cost }
        let subModels = source.subagentsByModel.sorted { $0.value.cost > $1.value.cost }
        let subTotal = source.subagentsByModel.values.reduce(0.0) { $0 + $1.cost }
        let subLA = source.subagentsByModel.values.reduce(0) { $0 + $1.linesAdded }
        let subLR = source.subagentsByModel.values.reduce(0) { $0 + $1.linesRemoved }

        return VStack(alignment: .leading, spacing: 5) {
            // Source header
            HStack(spacing: 0) {
                Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
                Text(" \(name)").font(.subheadline).fontWeight(.medium)
                Spacer(minLength: 2)
                addedCell(source.total.linesAdded, font: .caption)
                removedCell(source.total.linesRemoved, font: .caption)
                costCell(source.total.cost, font: .subheadline, weight: .semibold)
            }

            // Model rows
            ForEach(models, id: \.key) { model, stats in
                HStack(spacing: 0) {
                    Text(model).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 2)
                    addedCell(stats.linesAdded)
                    removedCell(stats.linesRemoved)
                    costCell(stats.cost)
                }
                .padding(.leading, 20)
            }

            if source.byModel.isEmpty && source.total.cost > 0 {
                Text("Model breakdown not available for older sessions")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.leading, 20)
            }

            // Subagents subsection
            if !source.subagentsByModel.isEmpty {
                HStack(spacing: 0) {
                    Image(systemName: "arrow.turn.down.right").font(.caption2).foregroundStyle(.secondary)
                    Text(" Subagents").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    addedCell(subLA)
                    removedCell(subLR)
                    costCell(subTotal)
                }
                .padding(.leading, 8)
                .padding(.top, 2)

                ForEach(subModels, id: \.key) { model, stats in
                    HStack(spacing: 0) {
                        Text(model).font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.tail)
                        Spacer(minLength: 2)
                        addedCell(stats.linesAdded)
                        removedCell(stats.linesRemoved)
                        costCell(stats.cost, font: .caption2)
                    }
                    .padding(.leading, 28)
                }
            }

            // Projects subsection
            let projects = source.byProject.sorted { ($0.value.main.cost + $0.value.subagents.cost) > ($1.value.main.cost + $1.value.subagents.cost) }
            if !projects.isEmpty {
                Text("Projects").font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                    .padding(.top, 4)

                ForEach(projects, id: \.key) { project, stats in
                    let totalCost = stats.main.cost + stats.subagents.cost
                    HStack(spacing: 0) {
                        Image(systemName: "folder").font(.caption2).foregroundStyle(.secondary)
                        Text(" \(project)").font(.caption).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 2)
                        addedCell(stats.main.linesAdded + stats.subagents.linesAdded)
                        removedCell(stats.main.linesRemoved + stats.subagents.linesRemoved)
                        costCell(totalCost)
                    }
                    .padding(.leading, 8)

                    if stats.subagents.cost > 0 {
                        HStack(spacing: 0) {
                            Image(systemName: "arrow.turn.down.right").font(.caption2).foregroundStyle(.secondary)
                            Text(" Subs").font(.caption2).foregroundStyle(.secondary)
                            Spacer(minLength: 2)
                            addedCell(stats.subagents.linesAdded)
                            removedCell(stats.subagents.linesRemoved)
                            costCell(stats.subagents.cost, font: .caption2)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
        }
    }
}
