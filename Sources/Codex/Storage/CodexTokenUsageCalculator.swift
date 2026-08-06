import Foundation

/**
 solid-name: CodexTokenUsageCalculator
 solid-category: service
 solid-description: Derives incremental token usage and cumulative high-water marks from Codex token reports.
 */
struct CodexTokenUsageCalculator: CodexTokenUsageCalculating {
    func delta(current: CodexTotalTokenUsage, previous: CodexTotalTokenUsage?) -> TokenUsage {
        let input = positiveDelta(current.inputTokens, previous?.inputTokens ?? 0)
        let cacheRead = min(positiveDelta(current.cachedInputTokens, previous?.cachedInputTokens ?? 0), input)
        let cacheWrite = min(
            positiveDelta(current.cacheWriteInputTokens, previous?.cacheWriteInputTokens ?? 0),
            input - cacheRead
        )
        return TokenUsage(
            inputTokens: input - cacheRead - cacheWrite,
            outputTokens: positiveDelta(current.outputTokens, previous?.outputTokens ?? 0),
            cacheCreationTokens: cacheWrite,
            cacheReadTokens: cacheRead
        )
    }

    func highWatermark(
        current: CodexTotalTokenUsage,
        previous: CodexTotalTokenUsage?
    ) -> CodexTotalTokenUsage {
        CodexTotalTokenUsage(
            inputTokens: max(current.inputTokens ?? 0, previous?.inputTokens ?? 0),
            cachedInputTokens: max(current.cachedInputTokens ?? 0, previous?.cachedInputTokens ?? 0),
            cacheWriteInputTokens: max(current.cacheWriteInputTokens ?? 0, previous?.cacheWriteInputTokens ?? 0),
            totalTokens: max(current.totalTokens ?? 0, previous?.totalTokens ?? 0),
            outputTokens: max(current.outputTokens ?? 0, previous?.outputTokens ?? 0)
        )
    }

    private func positiveDelta(_ current: Int?, _ previous: Int) -> Int {
        max(0, (current ?? 0) - previous)
    }
}
