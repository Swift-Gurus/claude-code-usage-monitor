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

// JSON shape from .agent.json files
private struct AgentJSON: Decodable {
    let pid: Int
    let model: String
    let agentName: String
    let contextPercent: Int
    let contextWindow: Int?
    let cost: Double
    let linesAdded: Int
    let linesRemoved: Int
    let workingDir: String
    let sessionID: String
    let durationMs: Double?
    let apiDurationMs: Double?
    let updatedAt: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case pid, model, cost
        case agentName = "agent_name"
        case contextPercent = "context_pct"
        case contextWindow = "context_window"
        case linesAdded = "lines_added"
        case linesRemoved = "lines_removed"
        case workingDir = "working_dir"
        case sessionID = "session_id"
        case durationMs = "duration_ms"
        case apiDurationMs = "api_duration_ms"
        case updatedAt = "updated_at"
    }
}

@Observable
public final class AgentTracker {
    public var activeAgents: [AgentInfo] = []

    private let usageDir: URL
    private let decoder = JSONDecoder()
    /// Cache: sessionID → (subagents dir mtime, per-model stats)
    private var subagentCache: [String: (mtime: Date, stats: [String: SourceModelStats])] = [:]

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
                      let json = try? decoder.decode(AgentJSON.self, from: data)
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

        // Re-evaluate idle: agent is active if it has CPU, was recently updated,
        // OR another agent in the same project is active
        activeAgents = agents.map { agent in
            let projectActive = activeWorkDirs.contains(agent.workingDir)
            let recentlyUpdated = Date().timeIntervalSince1970 - agent.updatedAt < 300
            let idle = agent.cpuUsage < 1.0 && !recentlyUpdated && !projectActive
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

        // Scan subagents for live sessions and write {pid}.subagents.json
        writeSubagentFiles(agents: activeAgents, todayStr: todayStr)
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

            // Check if subagents directory exists and get its mtime
            guard let attrs = try? fm.attributesOfItem(atPath: subagentsDir.path),
                  let mtime = attrs[.modificationDate] as? Date else { continue }

            // Use cache to avoid rescanning unchanged directories
            if let cached = subagentCache[agent.sessionID], cached.mtime == mtime { continue }

            let stats = JSONLParser.parseSubagents(in: subagentsDir)
            subagentCache[agent.sessionID] = (mtime: mtime, stats: stats)

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
            let details = JSONLParser.parseSubagentDetails(in: subagentsDir)
            if !details.isEmpty, let data = try? JSONEncoder().encode(details) {
                try? data.write(
                    to: todayDir.appendingPathComponent("\(agent.pid).subagent-details.json"),
                    options: .atomic
                )
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
