import Foundation

/**
 solid-name: CodexMessageStore
 solid-category: service
 solid-description: Retains and updates parsed Codex messages by index.
 */
final class CodexMessageStore: CodexMessageRetaining, CodexMessageReplacing {
    private var messages: [LogMessage] = []

    var parsedMessages: [LogMessage] {
        messages
    }

    func appendMessage(_ message: LogMessage) {
        messages.append(message)
    }

    func message(at index: Int) -> LogMessage? {
        guard messages.indices.contains(index) else { return nil }
        return messages[index]
    }

    func replaceMessage(_ message: LogMessage, at index: Int) {
        guard messages.indices.contains(index) else { return }
        messages[index] = message
    }
}
