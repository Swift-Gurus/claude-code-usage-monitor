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

        guard let files = try? fm.contentsOfDirectory(
            at: todayDir, includingPropertiesForKeys: nil
        ) else {
            activeAgents = []
            return
        }

        var agents: [AgentInfo] = []

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
            let recentlyUpdated = Date().timeIntervalSince1970 - json.updatedAt < 30
            let idle = cpu < 1.0 && !recentlyUpdated

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
                isIdle: idle
            ))
        }

        activeAgents = agents.sorted { $0.pid < $1.pid }
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
