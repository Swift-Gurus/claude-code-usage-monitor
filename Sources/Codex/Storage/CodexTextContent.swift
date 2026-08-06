import Foundation

/**
 solid-name: CodexTextContent
 solid-category: model
 solid-description: Represents Codex text output encoded as a string or a sequence of content blocks.
 */
enum CodexTextContent: Decodable {
    case text(String)
    case blocks([CodexMessageContent])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .text(value)
        } else {
            self = .blocks(try container.decode([CodexMessageContent].self))
        }
    }
}
