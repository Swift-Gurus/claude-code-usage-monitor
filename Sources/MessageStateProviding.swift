import Foundation

/**
 solid-name: MessageStateProviding
 solid-category: abstraction
 solid-description: Contract that defines the state interface for displaying log messages in a viewer.
 */
protocol MessageStateProviding: Observable {
    var messages: [LogMessage] { get }
    var displayedMessages: [LogMessage] { get }
    var isLoading: Bool { get }
    var pendingPrompt: LogToolCall? { get }
    var fileURL: URL { get }
    func roleLabel(_ msg: LogMessage) -> String
}