import Foundation

/**
 solid-name: CodexMessageContent
 solid-category: model
 solid-description: Represents a typed text block carried by a Codex message or tool result.
 */
struct CodexMessageContent: Decodable {
    let type: String
    let text: String?
}
