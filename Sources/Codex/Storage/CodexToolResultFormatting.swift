import Foundation

/**
 solid-name: CodexToolResultFormatting
 solid-category: abstraction
 solid-description: Contract for formatting Codex tool output and metadata as display text.
 */
protocol CodexToolResultFormatting {
    func format(rawValue: String?, decodedObject: [String: Any]?) -> String?
}
