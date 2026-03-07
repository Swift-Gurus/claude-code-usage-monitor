import Foundation

public enum AgentSource: String {
    case cli = "CLI"
    case commander = "Commander"
}

public struct AgentInfo: Identifiable {
    public let pid: Int
    public let model: String
    public let agentName: String
    public let contextPercent: Int
    public let contextWindow: Int
    public let cost: Double
    public let linesAdded: Int
    public let linesRemoved: Int
    public let workingDir: String
    public let sessionID: String
    public let durationMs: Double
    public let apiDurationMs: Double
    public let updatedAt: TimeInterval
    public let cpuUsage: Double
    public let isIdle: Bool
    public let source: AgentSource

    public var id: Int { pid }

    public var displayName: String {
        agentName.isEmpty ? model : agentName
    }

    public var shortDir: String {
        (workingDir as NSString).lastPathComponent
    }

    public var updatedAtDate: Date {
        Date(timeIntervalSince1970: updatedAt)
    }

    public var durationText: String {
        formatMs(durationMs)
    }

    public var apiDurationText: String {
        formatMs(apiDurationMs)
    }

    private func formatMs(_ ms: Double) -> String {
        let totalSec = Int(ms) / 1000
        let mins = totalSec / 60
        let secs = totalSec % 60
        if mins < 60 { return "\(mins)m \(secs)s" }
        return "\(mins / 60)h \(mins % 60)m"
    }

    public var contextWindowText: String {
        guard contextWindow > 0 else { return "" }
        let millions = Double(contextWindow) / 1_000_000.0
        if millions == Double(Int(millions)) {
            return "\(Int(millions))M"
        }
        return String(format: "%.1fM", millions)
    }

    public var idleDuration: TimeInterval {
        Date().timeIntervalSince(updatedAtDate)
    }

    public var idleText: String {
        let mins = Int(idleDuration) / 60
        if mins < 1 { return "" }
        if mins < 60 { return "\(mins)m idle" }
        return "\(mins / 60)h \(mins % 60)m idle"
    }

    public init(
        pid: Int, model: String, agentName: String, contextPercent: Int, contextWindow: Int,
        cost: Double, linesAdded: Int, linesRemoved: Int, workingDir: String, sessionID: String,
        durationMs: Double, apiDurationMs: Double, updatedAt: TimeInterval, cpuUsage: Double,
        isIdle: Bool, source: AgentSource
    ) {
        self.pid = pid
        self.model = model
        self.agentName = agentName
        self.contextPercent = contextPercent
        self.contextWindow = contextWindow
        self.cost = cost
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.workingDir = workingDir
        self.sessionID = sessionID
        self.durationMs = durationMs
        self.apiDurationMs = apiDurationMs
        self.updatedAt = updatedAt
        self.cpuUsage = cpuUsage
        self.isIdle = isIdle
        self.source = source
    }
}


@Observable
public final class AgentTracker {
    public var activeAgents: [AgentInfo] = []
    /// Subagent details keyed by PID — updated every reload cycle, drives reactive UI
    public var subagentDetails: [Int: [SubagentInfo]] = [:]
    /// Parent session tool counts keyed by PID — populated lazily when detail view opens
    public var parentToolCounts: [Int: [String: Int]] = [:]

    private let usageDir: URL
    private let decoder = JSONDecoder()
    /// Cache: sessionID → (max individual file mtime in subagents dir, per-model stats)
    /// Uses max file mtime (not dir mtime) to detect when existing subagent files grow.
    private var subagentCache: [String: (mtime: Date, stats: [String: SourceModelStats])] = [:]
    /// Cache: sessionID → (parent JSONL mtime, tool counts)
    private var parentToolCache: [String: (mtime: Date, counts: [String: Int])] = [:]
    /// Serial queue — ensures subagent scans never run concurrently, preventing data races
    private let subagentQueue = DispatchQueue(label: "com.swiftgurus.subagentScanner", qos: .utility)

    public init() {
        usageDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/usage")
    }

    public func reload() {
        let fm = FileManager.default
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFmt.string(from: Date())

        var agents: [AgentInfo] = []

        // Read .agent.json from CLI (statusline) and Commander folders.
        // No dedup needed — CommanderSupport already skips CLI-tracked PIDs.
        let dirs: [(URL, AgentSource)] = [
            (usageDir.appendingPathComponent(todayStr), .cli),
            (CommanderSupport.baseDir.appendingPathComponent(todayStr), .commander)
        ]

        for (todayDir, source) in dirs {
            guard let files = try? fm.contentsOfDirectory(
                at: todayDir, includingPropertiesForKeys: nil
            ) else { continue }

            for file in files where file.lastPathComponent.hasSuffix(".agent.json") {
                guard let data = try? Data(contentsOf: file),
                      let json = try? decoder.decode(AgentFileData.self, from: data)
                else { continue }

                let pid32 = Int32(json.pid)

                // Check PID liveness — remove file if process is dead
                guard kill(pid32, 0) == 0 else {
                    try? fm.removeItem(at: file)
                    continue
                }

                let cpu = Self.cpuUsage(for: json.pid)

                agents.append(AgentInfo(
                    pid: json.pid,
                    model: json.model,
                    agentName: json.agentName,
                    contextPercent: json.contextPercent,
                    contextWindow: json.contextWindow ?? 0,
                    cost: json.cost,
                    linesAdded: json.linesAdded,
                    linesRemoved: json.linesRemoved,
                    workingDir: json.workingDir,
                    sessionID: json.sessionID,
                    durationMs: json.durationMs ?? 0,
                    apiDurationMs: json.apiDurationMs ?? 0,
                    updatedAt: json.updatedAt,
                    cpuUsage: cpu,
                    isIdle: true, // recalculated below
                    source: source
                ))
            }
        }

        // Build set of active working dirs (any agent with CPU > 0 makes the dir active)
        let activeWorkDirs = Set(
            agents.filter { $0.cpuUsage >= 1.0 }.map(\.workingDir)
        )

        // Check JSONL activity: if parent or any subagent JSONL modified within 60s, agent is active
        let projectsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        var jsonlActivePIDs = Set<Int>()
        let now = Date()
        let modKey: URLResourceKey = .contentModificationDateKey
        for agent in agents where !agent.sessionID.isEmpty {
            let encoded = SessionScanner.encodeProjectPath(agent.workingDir)
            let sessionDir = projectsDir.appendingPathComponent(encoded)

            // Check parent session JSONL mtime
            let parentJSONL = sessionDir.appendingPathComponent("\(agent.sessionID).jsonl")
            if let attrs = try? fm.attributesOfItem(atPath: parentJSONL.path),
               let mtime = attrs[.modificationDate] as? Date,
               now.timeIntervalSince(mtime) < 60 {
                jsonlActivePIDs.insert(agent.pid)
                continue
            }

            // Check subagent JSONL mtimes
            let subagentsDir = sessionDir
                .appendingPathComponent(agent.sessionID)
                .appendingPathComponent("subagents")
            guard fm.fileExists(atPath: subagentsDir.path) else { continue }
            let files = (try? fm.contentsOfDirectory(at: subagentsDir, includingPropertiesForKeys: [modKey])) ?? []
            let maxMtime = files.compactMap {
                try? $0.resourceValues(forKeys: [modKey]).contentModificationDate
            }.max()
            if let mtime = maxMtime, now.timeIntervalSince(mtime) < 60 {
                jsonlActivePIDs.insert(agent.pid)
            }
        }

        // Re-evaluate idle: agent is active if it has CPU, was recently updated,
        // another agent in the same project is active, OR subagents are actively running
        activeAgents = agents.map { agent in
            let projectActive = activeWorkDirs.contains(agent.workingDir)
            let recentlyUpdated = Date().timeIntervalSince1970 - agent.updatedAt < 60
            let subagentsActive = jsonlActivePIDs.contains(agent.pid)
            let idle = agent.cpuUsage < 1.0 && !recentlyUpdated && !projectActive && !subagentsActive
            guard idle != agent.isIdle else { return agent }
            return AgentInfo(
                pid: agent.pid, model: agent.model, agentName: agent.agentName,
                contextPercent: agent.contextPercent, contextWindow: agent.contextWindow,
                cost: agent.cost,
                linesAdded: agent.linesAdded, linesRemoved: agent.linesRemoved,
                workingDir: agent.workingDir, sessionID: agent.sessionID,
                durationMs: agent.durationMs, apiDurationMs: agent.apiDurationMs,
                updatedAt: agent.updatedAt, cpuUsage: agent.cpuUsage, isIdle: idle,
                source: agent.source
            )
        }.sorted { $0.pid < $1.pid }

        // Scan subagents on dedicated serial queue — prevents data races and blocks main thread
        let agentsSnapshot = activeAgents
        subagentQueue.async { [weak self] in
            self?.writeSubagentFiles(agents: agentsSnapshot, todayStr: todayStr)
        }
    }

    private func writeSubagentFiles(agents: [AgentInfo], todayStr: String) {
        let fm = FileManager.default
        let projectsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")

        for agent in agents where !agent.sessionID.isEmpty {
            let encoded = SessionScanner.encodeProjectPath(agent.workingDir)
            let subagentsDir = projectsDir
                .appendingPathComponent(encoded)
                .appendingPathComponent(agent.sessionID)
                .appendingPathComponent("subagents")

            guard fm.fileExists(atPath: subagentsDir.path) else { continue }

            // Use max individual file mtime — detects both new files AND growth in existing files
            let files = (try? fm.contentsOfDirectory(at: subagentsDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            let maxMtime = files.compactMap {
                try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            }.max() ?? Date.distantPast
            guard subagentCache[agent.sessionID]?.mtime != maxMtime else { continue }

            let stats = JSONLParser.parseSubagents(in: subagentsDir)
            subagentCache[agent.sessionID] = (mtime: maxMtime, stats: stats)

            // Write {pid}.subagents.json to usage folder so UsageData can read it
            let todayDir: URL
            switch agent.source {
            case .cli:
                todayDir = usageDir.appendingPathComponent(todayStr)
            case .commander:
                todayDir = CommanderSupport.baseDir.appendingPathComponent(todayStr)
            }

            if let data = try? JSONEncoder().encode(stats) {
                try? data.write(
                    to: todayDir.appendingPathComponent("\(agent.pid).subagents.json"),
                    options: .atomic
                )
            }

            // Write per-subagent detail for drill-down view
            let meta = JSONLParser.parseSubagentMeta(sessionID: agent.sessionID, workingDir: agent.workingDir)
            let details = JSONLParser.parseSubagentDetails(in: subagentsDir, meta: meta)
            if !details.isEmpty {
                if let data = try? JSONEncoder().encode(details) {
                    try? data.write(
                        to: todayDir.appendingPathComponent("\(agent.pid).subagent-details.json"),
                        options: .atomic
                    )
                }
                let pid = agent.pid
                DispatchQueue.main.async { [weak self] in
                    self?.subagentDetails[pid] = details
                }
            }

            // Parse parent session tool counts (CLI + Commander), cached by JSONL mtime
            guard !agent.sessionID.isEmpty else { continue }
            let projectsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
            let jsonlURL = projectsDir
                .appendingPathComponent(SessionScanner.encodeProjectPath(agent.workingDir))
                .appendingPathComponent("\(agent.sessionID).jsonl")
            if let jsonlAttrs = try? fm.attributesOfItem(atPath: jsonlURL.path),
               let jsonlMtime = jsonlAttrs[.modificationDate] as? Date {
                if parentToolCache[agent.sessionID]?.mtime != jsonlMtime {
                    let counts = JSONLParser.parseParentTools(sessionID: agent.sessionID, workingDir: agent.workingDir)
                    parentToolCache[agent.sessionID] = (mtime: jsonlMtime, counts: counts)
                    if !counts.isEmpty, let data = try? JSONEncoder().encode(counts) {
                        try? data.write(
                            to: todayDir.appendingPathComponent("\(agent.pid).parent-tools.json"),
                            options: .atomic
                        )
                    }
                }
                if let counts = parentToolCache[agent.sessionID]?.counts, !counts.isEmpty {
                    let pid = agent.pid
                    DispatchQueue.main.async { [weak self] in
                        self?.parentToolCounts[pid] = counts
                    }
                }
            }
        }
    }

    /// Get CPU usage for a PID via `ps`
    private static func cpuUsage(for pid: Int) -> Double {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "%cpu="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespaces) ?? ""
            return Double(output) ?? 0
        } catch {
            return 0
        }
    }
}
