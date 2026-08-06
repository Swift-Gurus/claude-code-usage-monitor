import Foundation

/**
 solid-name: TokenUsagePresenceChecking
 solid-category: abstraction
 solid-description: Contract for determining whether token usage contains reportable activity.
 */
protocol TokenUsagePresenceChecking {
    func hasUsage(_ usage: TokenUsage) -> Bool
}
