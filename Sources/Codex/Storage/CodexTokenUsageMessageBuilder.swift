import Foundation

/**
 solid-name: CodexTokenUsageMessageBuilder
 solid-category: service
 solid-description: Builds incremental token-usage messages from Codex reports.
 */
struct CodexTokenUsageMessageBuilder: CodexTokenUsageMessageBuilding {
    private let usageCalculator: CodexTokenUsageCalculating
    private let presenceChecker: TokenUsagePresenceChecking
    private let includesMessages: Bool

    init(
        usageCalculator: CodexTokenUsageCalculating = CodexTokenUsageCalculator(),
        presenceChecker: TokenUsagePresenceChecking = TokenUsagePresenceChecker(),
        includesMessages: Bool = true
    ) {
        self.usageCalculator = usageCalculator
        self.presenceChecker = presenceChecker
        self.includesMessages = includesMessages
    }

    func message(
        for payload: CodexRolloutPayload,
        offset: Int,
        timestamp: Date?,
        cumulativeUsage: inout CodexTotalTokenUsage?
    ) -> LogMessage? {
        guard includesMessages, let totalUsage = payload.info?.totalTokenUsage else { return nil }

        let usage = usageCalculator.delta(current: totalUsage, previous: cumulativeUsage)
        cumulativeUsage = usageCalculator.highWatermark(current: totalUsage, previous: cumulativeUsage)
        guard presenceChecker.hasUsage(usage) else { return nil }

        var message = LogMessage(
            id: "codex-usage-\(offset)",
            role: .assistant,
            model: nil,
            timestamp: timestamp,
            thinking: nil,
            textContent: [],
            toolCalls: [],
            toolResultIDs: [],
            toolResponses: [:],
            toolResultContents: [:]
        )
        message.usage = usage
        return message
    }
}
