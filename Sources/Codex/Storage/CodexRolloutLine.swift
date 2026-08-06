import Foundation

/**
 solid-name: CodexRolloutLine
 solid-category: model
 solid-description: Represents a timestamped record in a Codex rollout.
 */
struct CodexRolloutLine: Decodable {
    let timestamp: String?
    let type: String
    let payload: CodexRolloutPayload?
}
