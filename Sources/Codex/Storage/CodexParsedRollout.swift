import Foundation

/**
 solid-name: CodexParsedRollout
 solid-category: model
 solid-description: Represents the session metadata and usage derived from a Codex rollout.
 */
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
