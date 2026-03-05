import Foundation

/// Token usage from a session or API call.
struct TokenUsage {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
}

/// Per-million-token pricing for a model.
/// Source: https://platform.claude.com/docs/en/about-claude/pricing
/// Last updated: 2026-03-05
struct ModelPricing {
    let inputPerMTok: Double
    let outputPerMTok: Double
    let cacheWritePerMTok: Double
    let cacheReadPerMTok: Double
}

/// Computes USD cost from token usage and model pricing.
enum PriceCalculator {

    static func cost(for usage: TokenUsage, model: ClaudeModel) -> Double {
        let p = model.pricing
        return Double(usage.inputTokens) * p.inputPerMTok / 1_000_000
            + Double(usage.outputTokens) * p.outputPerMTok / 1_000_000
            + Double(usage.cacheCreationTokens) * p.cacheWritePerMTok / 1_000_000
            + Double(usage.cacheReadTokens) * p.cacheReadPerMTok / 1_000_000
    }
}
