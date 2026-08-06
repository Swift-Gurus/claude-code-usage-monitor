import Foundation

/**
 solid-name: CodexMessageRetaining
 solid-category: abstraction
 solid-description: Contract for retaining parsed Codex messages.
 */
protocol CodexMessageRetaining: AnyObject {
    var parsedMessages: [LogMessage] { get }
    func appendMessage(_ message: LogMessage)
}
