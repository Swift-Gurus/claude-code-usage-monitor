import Foundation

/**
 solid-name: CodexReasoningDuplicateChecking
 solid-category: abstraction
 solid-description: Contract for detecting reasoning text already represented by nearby Codex messages.
 */
protocol CodexReasoningDuplicateChecking {
    func isDuplicate(text: String, timestamp: Date?, messages: [LogMessage]) -> Bool
}
