import Foundation

/**
 solid-name: CodexTokenInfo
 solid-category: model
 solid-description: Represents cumulative, recent, and contextual token usage reported by Codex.
 */
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
