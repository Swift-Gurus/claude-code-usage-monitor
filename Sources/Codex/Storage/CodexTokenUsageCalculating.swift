import Foundation

/**
 solid-name: CodexTokenUsageCalculating
 solid-category: abstraction
 solid-description: Contract for deriving incremental and cumulative token totals from Codex reports.
 */
protocol CodexTokenUsageCalculating {
    func delta(current: CodexTotalTokenUsage, previous: CodexTotalTokenUsage?) -> TokenUsage
    func highWatermark(current: CodexTotalTokenUsage, previous: CodexTotalTokenUsage?) -> CodexTotalTokenUsage
}
