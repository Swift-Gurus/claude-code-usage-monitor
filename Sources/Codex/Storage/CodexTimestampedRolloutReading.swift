import Foundation

/**
 solid-name: CodexTimestampedRolloutReading
 solid-category: abstraction
 solid-description: Contract for reading timestamped Codex rollout payloads from storage.
 */
protocol CodexTimestampedRolloutReading {
    func readRollouts(at url: URL) -> [CodexTimestampedRollout]
}
