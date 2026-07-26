import Foundation

public struct CodexSession: Identifiable {
    public let threadID: String
    public let title: String
    public let cwd: String
    public let model: String
    public let updatedAt: Date
    public let startedAt: Date
    public let totalTokens: Int
    public let currentContextTokens: Int
    public let contextWindow: Int
    public let rateLimits: RateLimits?

    public var id: String { threadID }
}

public struct CodexRolloutEvent: Identifiable, Hashable {
    public let id: String
    public let timestamp: Date?
    public let kind: String
    public let summary: String
}
