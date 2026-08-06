import Foundation

/**
 solid-name: CodexTotalTokenUsage
 solid-category: model
 solid-description: Represents input, cache, output, and total token usage reported by Codex.
 */
struct CodexTotalTokenUsage: Decodable {
    let inputTokens: Int?
    let cachedInputTokens: Int?
    let cacheWriteInputTokens: Int?
    let totalTokens: Int?
    let outputTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case cacheWriteInputTokens = "cache_write_input_tokens"
        case totalTokens = "total_tokens"
        case outputTokens = "output_tokens"
    }
}
