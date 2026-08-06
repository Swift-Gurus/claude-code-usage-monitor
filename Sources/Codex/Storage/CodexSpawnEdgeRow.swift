import Foundation

/**
 solid-name: CodexSpawnEdgeRow
 solid-category: model
 solid-description: Represents the child thread in a Codex parent-child relationship.
 */
struct CodexSpawnEdgeRow: Decodable {
    let childThreadID: String

    private enum CodingKeys: String, CodingKey {
        case childThreadID = "child_thread_id"
    }
}
