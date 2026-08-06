import Foundation

/**
 solid-name: CodexEventDurationFormatter
 solid-category: utility
 solid-description: Formats Codex event durations as display text.
 */
struct CodexEventDurationFormatter: CodexEventDurationFormatting {
    func format(_ duration: CodexEventDuration?) -> String? {
        guard let duration else { return nil }
        let seconds = Double(duration.secs) + Double(duration.nanos) / 1_000_000_000
        return String(format: "duration: %.3fs", seconds)
    }
}
