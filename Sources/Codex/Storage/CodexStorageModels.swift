import Foundation

struct CodexStateThread {
    let id: String
    let title: String
    let cwd: String
    let model: String
    let updatedAt: Date
    let createdAt: Date
    let tokensUsed: Int
}

struct CodexParsedRollout {
    let threadID: String
    let title: String
    let cwd: String
    let model: String
    let updatedAt: Date
    let startedAt: Date
    let totalTokens: Int
    let currentContextTokens: Int
    let contextWindow: Int
    let rateLimits: RateLimits?
}

struct CodexThreadRow: Decodable {
    let id: String
    let title: String
    let cwd: String
    let updatedAt: Double
    let createdAt: Double
    let model: String
    let tokensUsed: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case cwd
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case model
        case tokensUsed = "tokens_used"
    }
}

struct CodexSpawnEdgeRow: Decodable {
    let childThreadID: String

    private enum CodingKeys: String, CodingKey {
        case childThreadID = "child_thread_id"
    }
}

struct CodexSessionIndexRow: Decodable {
    let id: String
    let threadName: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case threadName = "thread_name"
    }
}

struct CodexRolloutLine: Decodable {
    let timestamp: String?
    let type: String
    let payload: CodexRolloutPayload?
}

struct CodexRolloutPayload: Decodable {
    let source: String?
    let cwd: String?
    let model: String?
    let title: String?
    let timestamp: String?
    let type: String?
    let role: String?
    let phase: String?
    let status: String?
    let info: CodexTokenInfo?
    let rateLimits: CodexRateLimitInfo?
    let content: [CodexMessageContent]?
    let message: String?
    let name: String?
    let arguments: String?
    let input: String?
    let callID: String?
    let output: String?
    let stdout: String?
    let stderr: String?
    let aggregatedOutput: String?
    let success: Bool?

    private enum CodingKeys: String, CodingKey {
        case source
        case cwd
        case model
        case title
        case timestamp
        case type
        case role
        case phase
        case status
        case info
        case rateLimits = "rate_limits"
        case content
        case message
        case name
        case arguments
        case input
        case callID = "call_id"
        case output
        case stdout
        case stderr
        case aggregatedOutput = "aggregated_output"
        case success
    }
}

struct CodexRateLimitInfo: Decodable {
    let primary: CodexRateLimitWindow?
    let secondary: CodexRateLimitWindow?
}

struct CodexRateLimitWindow: Decodable {
    let usedPercent: Double?
    let resetsAt: Double?

    private enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetsAt = "resets_at"
    }
}

struct CodexTokenInfo: Decodable {
    let totalTokenUsage: CodexTotalTokenUsage?
    let lastTokenUsage: CodexTotalTokenUsage?
    let modelContextWindow: Int?

    private enum CodingKeys: String, CodingKey {
        case totalTokenUsage = "total_token_usage"
        case lastTokenUsage = "last_token_usage"
        case modelContextWindow = "model_context_window"
    }
}

struct CodexTotalTokenUsage: Decodable {
    let totalTokens: Int?
    let outputTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case outputTokens = "output_tokens"
    }
}
