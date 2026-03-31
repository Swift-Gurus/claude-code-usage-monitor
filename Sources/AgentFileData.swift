import Foundation

/// Codable representation of .agent.json files.
/// Used for both writing (CommanderSupport) and reading (AgentTracker).
/// Rate limit window data (5-hour or 7-day).
public struct RateLimitWindow: Codable {
    public let usedPercentage: Double?
    public let resetsAt: Double?  // Unix epoch seconds

    public init(usedPercentage: Double? = nil, resetsAt: Double? = nil) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }

    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_pct"
        case resetsAt = "resets_at"
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 2
        return f
    }()

    /// Time remaining until reset, e.g. "2h 19m" or "6d 23h".
    public var resetsInText: String? {
        guard let resets = resetsAt else { return nil }
        let remaining = resets - Date().timeIntervalSince1970
        guard remaining > 0 else { return nil }
        return Self.durationFormatter.string(from: remaining)
    }
}

/// Rate limits from statusline (Pro/Max plans only).
public struct RateLimits: Codable {
    public let fiveHour: RateLimitWindow?
    public let sevenDay: RateLimitWindow?

    public init(fiveHour: RateLimitWindow? = nil, sevenDay: RateLimitWindow? = nil) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    /// True if any rate limit data is available.
    public var hasData: Bool {
        (fiveHour?.usedPercentage != nil) || (sevenDay?.usedPercentage != nil)
    }
}

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
    public let rateLimits: RateLimits?

    public init(
        pid: Int, model: String, agentName: String,
        contextPercent: Int, contextWindow: Int?,
        cost: Double, linesAdded: Int, linesRemoved: Int,
        workingDir: String, sessionID: String,
        durationMs: Double?, apiDurationMs: Double?,
        updatedAt: TimeInterval,
        rateLimits: RateLimits? = nil
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
        self.rateLimits = rateLimits
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
        case rateLimits = "rate_limits"
    }
}
