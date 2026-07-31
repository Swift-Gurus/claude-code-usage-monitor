import Foundation

/**
 solid-name: LogMessageParsing
 solid-category: abstraction
 solid-description: Contract that defines a message parsing interface with pluggable implementations.
 */
protocol LogMessageParsing {
    func parseMessages(at url: URL) -> [LogMessage]
}
