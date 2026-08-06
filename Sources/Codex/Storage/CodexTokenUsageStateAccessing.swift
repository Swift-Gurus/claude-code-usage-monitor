import Foundation

/**
 solid-name: CodexTokenUsageStateAccessing
 solid-category: abstraction
 solid-description: Contract for reading and updating cumulative Codex token usage during parsing.
 */
protocol CodexTokenUsageStateAccessing: AnyObject {
    var cumulativeTokenUsage: CodexTotalTokenUsage? { get set }
}
