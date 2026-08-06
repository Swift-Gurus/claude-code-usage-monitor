import Foundation

/**
 solid-name: CodexTokenUsageState
 solid-category: model
 solid-description: Retains cumulative Codex token usage during rollout parsing.
 */
final class CodexTokenUsageState: CodexTokenUsageStateAccessing {
    var cumulativeTokenUsage: CodexTotalTokenUsage?
}
