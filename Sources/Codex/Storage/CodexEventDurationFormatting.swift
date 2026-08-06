import Foundation

/**
 solid-name: CodexEventDurationFormatting
 solid-category: abstraction
 solid-description: Contract for formatting Codex event durations as display text.
 */
protocol CodexEventDurationFormatting {
    func format(_ duration: CodexEventDuration?) -> String?
}
