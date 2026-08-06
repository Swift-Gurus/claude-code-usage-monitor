import Foundation

/**
 solid-name: CodexTokenUsageMessageBuilding
 solid-category: abstraction
 solid-description: Contract for building incremental token-usage messages from Codex reports.
 */
protocol CodexTokenUsageMessageBuilding {
    func message(
        for payload: CodexRolloutPayload,
        offset: Int,
        timestamp: Date?,
        cumulativeUsage: inout CodexTotalTokenUsage?
    ) -> LogMessage?
}
