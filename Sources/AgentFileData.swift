import Foundation

/// Codable representation of .agent.json files.
/// Used for both writing (CommanderSupport) and reading (AgentTracker).
public struct AgentFileData: Codable {
    public let pid: Int
    public let model: String
    public let agentName: String
    public let contextPercent: Int
    public let contextWindow: Int?
    public let cost: Double
    public let linesAdded: Int
    public let linesRemoved: Int
    public let workingDir: String
    public let sessionID: String
    public let durationMs: Double?
    public let apiDurationMs: Double?
    public let updatedAt: TimeInterval

    public init(
        pid: Int, model: String, agentName: String,
        contextPercent: Int, contextWindow: Int?,
        cost: Double, linesAdded: Int, linesRemoved: Int,
        workingDir: String, sessionID: String,
        durationMs: Double?, apiDurationMs: Double?,
        updatedAt: TimeInterval
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
    }

    enum CodingKeys: String, CodingKey {
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
