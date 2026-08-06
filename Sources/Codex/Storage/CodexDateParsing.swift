import Foundation

/**
 solid-name: CodexDateParsing
 solid-category: abstraction
 solid-description: Contract for parsing Codex timestamp text into dates.
 */
protocol CodexDateParsing {
    func parse(_ rawValue: String) -> Date?
}
