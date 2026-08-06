import Foundation

/**
 solid-name: CodexTimestampedRollout
 solid-category: model
 solid-description: Represents a decoded Codex rollout payload with ordering and timestamp context.
 */
struct CodexTimestampedRollout {
    let type: String
    let payload: CodexRolloutPayload
    let offset: Int
    let timestamp: Date?
}
