import Foundation

/// Token usage from a session or API call.
public struct TokenUsage {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int

    public init(inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
    }
}

/// Per-million-token pricing for a model.
/// Source: https://platform.claude.com/docs/en/about-claude/pricing
/// Last updated: 2026-03-05
public struct ModelPricing {
    public let inputPerMTok: Double
    public let outputPerMTok: Double
    public let cacheWritePerMTok: Double
    public let cacheReadPerMTok: Double

    public init(inputPerMTok: Double, outputPerMTok: Double, cacheWritePerMTok: Double, cacheReadPerMTok: Double) {
        self.inputPerMTok = inputPerMTok
        self.outputPerMTok = outputPerMTok
        self.cacheWritePerMTok = cacheWritePerMTok
        self.cacheReadPerMTok = cacheReadPerMTok
    }
}

/// Computes USD cost from token usage and model pricing.
public enum PriceCalculator {

    public static func cost(for usage: TokenUsage, model: ClaudeModel) -> Double {
        let p = model.pricing
        return Double(usage.inputTokens) * p.inputPerMTok / 1_000_000
            + Double(usage.outputTokens) * p.outputPerMTok / 1_000_000
            + Double(usage.cacheCreationTokens) * p.cacheWritePerMTok / 1_000_000
            + Double(usage.cacheReadTokens) * p.cacheReadPerMTok / 1_000_000
    }
}
