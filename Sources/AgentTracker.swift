import Foundation

struct AgentInfo: Identifiable, Decodable {
    let pid: Int
    let model: String
    let agentName: String
    let contextPercent: Int
    let cost: Double
    let linesAdded: Int
    let linesRemoved: Int
    let workingDir: String
    let sessionID: String
    let updatedAt: TimeInterval

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

    var idleDuration: TimeInterval {
        Date().timeIntervalSince(updatedAtDate)
    }

    var isIdle: Bool {
        idleDuration >= 60 // idle after 1 minute
    }

    var idleText: String {
        let mins = Int(idleDuration) / 60
        if mins < 1 { return "" }
        if mins < 60 { return "\(mins)m idle" }
        return "\(mins / 60)h \(mins % 60)m idle"
    }

    private enum CodingKeys: String, CodingKey {
        case pid
        case model
        case agentName = "agent_name"
        case contextPercent = "context_pct"
        case cost
        case linesAdded = "lines_added"
        case linesRemoved = "lines_removed"
        case workingDir = "working_dir"
        case sessionID = "session_id"
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
                  let agent = try? decoder.decode(AgentInfo.self, from: data)
            else { continue }

            // Check PID liveness — remove file if process is dead
            guard kill(Int32(agent.pid), 0) == 0 else {
                try? fm.removeItem(at: file)
                continue
            }

            agents.append(agent)
        }

        activeAgents = agents.sorted { $0.pid < $1.pid }
    }
}
