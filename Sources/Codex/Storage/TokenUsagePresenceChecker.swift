import Foundation

/**
 solid-name: TokenUsagePresenceChecker
 solid-category: service
 solid-description: Determines whether token usage contains reportable input, output, or cache activity.
 */
struct TokenUsagePresenceChecker: TokenUsagePresenceChecking {
    func hasUsage(_ usage: TokenUsage) -> Bool {
        usage.inputTokens > 0
            || usage.outputTokens > 0
            || usage.cacheCreationTokens > 0
            || usage.cacheReadTokens > 0
    }
}
