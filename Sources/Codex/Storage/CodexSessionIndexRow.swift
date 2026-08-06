import Foundation

/**
 solid-name: CodexSessionIndexRow
 solid-category: model
 solid-description: Represents the identifier and optional display name of an indexed Codex session.
 */
struct CodexSessionIndexRow: Decodable {
    let id: String
    let threadName: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case threadName = "thread_name"
    }
}
