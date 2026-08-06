import Foundation

/**
 solid-name: CodexMessageReplacing
 solid-category: abstraction
 solid-description: Contract for retrieving and replacing retained Codex messages by index.
 */
protocol CodexMessageReplacing: AnyObject {
    func message(at index: Int) -> LogMessage?
    func replaceMessage(_ message: LogMessage, at index: Int)
}
