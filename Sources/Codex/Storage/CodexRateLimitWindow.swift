import Foundation

/**
 solid-name: CodexRateLimitWindow
 solid-category: model
 solid-description: Represents usage percentage and reset timing for a Codex rate limit.
 */
struct CodexRateLimitWindow: Decodable {
    let usedPercent: Double?
    let resetsAt: Double?

    private enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetsAt = "resets_at"
    }
}
