import Foundation

/// Exact session/turn-level token totals, deduped by assistant message id upstream.
public struct SessionTokenStats: Equatable {
    public var inputTokens = 0
    public var outputTokens = 0
    public var cacheCreationTokens = 0
    public var cacheReadTokens = 0

    /// Fraction of context-window input that was served from cache. 0 when there's no
    /// input activity at all (never NaN).
    public var cacheHitRate: Double {
        let denom = inputTokens + cacheCreationTokens + cacheReadTokens
        guard denom > 0 else { return 0 }
        return Double(cacheReadTokens) / Double(denom)
    }

    public init(inputTokens: Int = 0, outputTokens: Int = 0, cacheCreationTokens: Int = 0, cacheReadTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
    }

    public mutating func add(_ usage: TokenUsage) {
        inputTokens += usage.inputTokens
        outputTokens += usage.outputTokens
        cacheCreationTokens += usage.cacheCreationTokens
        cacheReadTokens += usage.cacheReadTokens
    }

    public mutating func merge(_ other: SessionTokenStats) {
        inputTokens += other.inputTokens
        outputTokens += other.outputTokens
        cacheCreationTokens += other.cacheCreationTokens
        cacheReadTokens += other.cacheReadTokens
    }
}
