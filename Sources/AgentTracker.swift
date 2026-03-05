import Foundation

struct AgentInfo: Identifiable {
    let pid: Int
    let model: String
    let agentName: String
    let contextPercent: Int
    let cost: Double
    let linesAdded: Int
    let linesRemoved: Int
    let workingDir: String
    let sessionID: String
    let durationMs: Double
    let apiDurationMs: Double
    let updatedAt: TimeInterval
    let cpuUsage: Double
    let isIdle: Bool

    var id: Int { pid }

    var displayName: String {
        agentName.isEmpty ? model : agentName
    }

    var shortDir: String {
        (workingDir as NSString).lastPathComponent
    }

    var updatedAtDate: Date {
        Date(timeIntervalSince1970: updatedAt)
    }

    var durationText: String {
        formatMs(durationMs)
    }

    var apiDurationText: String {
        formatMs(apiDurationMs)
    }

    private func formatMs(_ ms: Double) -> String {
        let totalSec = Int(ms) / 1000
        let mins = totalSec / 60
        let secs = totalSec % 60
        if mins < 60 { return "\(mins)m \(secs)s" }
        return "\(mins / 60)h \(mins % 60)m"
    }

    var idleDuration: TimeInterval {
        Date().timeIntervalSince(updatedAtDate)
    }

    var idleText: String {
        let mins = Int(idleDuration) / 60
        if mins < 1 { return "" }
        if mins < 60 { return "\(mins)m idle" }
        return "\(mins / 60)h \(mins % 60)m idle"
    }
}

// JSON shape from .agent.json files
private struct AgentJSON: Decodable {
    let pid: Int
    let model: String
    let agentName: String
    let contextPercent: Int
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
final class AgentTracker {
    var activeAgents: [AgentInfo] = []

    private let usageDir: URL
    private let decoder = JSONDecoder()

    init() {
        usageDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/usage")
    }

    func reload() {
        let fm = FileManager.default
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let todayDir = usageDir.appendingPathComponent(dateFmt.string(from: Date()))

        var agents: [AgentInfo] = []

        // --- Step 1: Update .dat/.agent.json for active Commander sessions ---
        // Must run BEFORE reading .agent.json files so Source 2 below gets fresh data.
        Self.updateCommanderSessions(in: todayDir)

        // --- Step 2: Read all .agent.json files (statusline + Commander-written) ---
        if let files = try? fm.contentsOfDirectory(
            at: todayDir, includingPropertiesForKeys: nil
        ) {
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
                    cost: json.cost,
                    linesAdded: json.linesAdded,
                    linesRemoved: json.linesRemoved,
                    workingDir: json.workingDir,
                    sessionID: json.sessionID,
                    durationMs: json.durationMs ?? 0,
                    apiDurationMs: json.apiDurationMs ?? 0,
                    updatedAt: json.updatedAt,
                    cpuUsage: cpu,
                    isIdle: true // recalculated below
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
                contextPercent: agent.contextPercent, cost: agent.cost,
                linesAdded: agent.linesAdded, linesRemoved: agent.linesRemoved,
                workingDir: agent.workingDir, sessionID: agent.sessionID,
                durationMs: agent.durationMs, apiDurationMs: agent.apiDurationMs,
                updatedAt: agent.updatedAt, cpuUsage: agent.cpuUsage, isIdle: idle
            )
        }.sorted { $0.pid < $1.pid }
    }

    /// Parse JSONL for all active Commander sessions and write fresh .dat/.agent.json files.
    /// Returns the set of PIDs that were updated (for reference, though not currently needed).
    @discardableResult
    private static func updateCommanderSessions(in todayDir: URL) -> Set<Int> {
        let activeSessions = SessionScanner.findActiveSessions()
        var pids: Set<Int> = []

        for session in activeSessions {
            guard let usage = JSONLParser.parseSession(
                at: session.jsonlURL,
                sessionID: session.sessionID,
                workingDir: session.workingDir
            ) else { continue }

            let durationMs = usage.lastUpdatedAt.timeIntervalSince(usage.startedAt) * 1000
            pids.insert(session.pid)

            // Write .dat so UsageData aggregates this session's cost
            try? FileManager.default.createDirectory(at: todayDir, withIntermediateDirectories: true)
            let datContent = "\(usage.costUSD) 0 0\n"
            try? datContent.write(
                to: todayDir.appendingPathComponent("\(session.pid).dat"),
                atomically: true, encoding: .utf8
            )

            // Write .agent.json so the agent shows up in the UI
            let json: [String: Any] = [
                "pid": session.pid,
                "model": usage.displayModel,
                "agent_name": usage.agentName,
                "context_pct": usage.contextPercent,
                "cost": usage.costUSD,
                "lines_added": 0,
                "lines_removed": 0,
                "working_dir": usage.workingDir,
                "session_id": usage.sessionID,
                "duration_ms": durationMs,
                "api_duration_ms": 0,
                "updated_at": Int(Date().timeIntervalSince1970)
            ]
            if let data = try? JSONSerialization.data(withJSONObject: json) {
                try? data.write(
                    to: todayDir.appendingPathComponent("\(session.pid).agent.json"),
                    options: .atomic
                )
            }
        }
        return pids
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
