import Foundation

/**
 solid-name: CodexEventDuration
 solid-category: model
 solid-description: Represents seconds and nanoseconds reported for a Codex event duration.
 */
struct CodexEventDuration: Decodable {
    let secs: Int
    let nanos: Int
}
