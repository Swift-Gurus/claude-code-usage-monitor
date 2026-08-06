import Foundation

/**
 solid-name: CodexUserMessageDuplicateChecking
 solid-category: abstraction
 solid-description: Contract for detecting mirrored Codex user messages by text and timestamp.
 */
protocol CodexUserMessageDuplicateChecking {
    func isDuplicate(text: String, timestamp: Date?, messages: [LogMessage]) -> Bool
}
