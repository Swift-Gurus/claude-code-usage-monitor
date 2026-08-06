import Foundation

/**
 solid-name: CodexTextContentResolver
 solid-category: service
 solid-description: Resolves flexible Codex output values into display text.
 */
struct CodexTextContentResolver: CodexTextContentResolving {
    func text(from content: CodexTextContent?) -> String? {
        switch content {
        case .text(let value):
            return value
        case .blocks(let blocks):
            let values = blocks.compactMap(\.text).filter { !$0.isEmpty }
            return values.isEmpty ? nil : values.joined(separator: "\n")
        case nil:
            return nil
        }
    }
}
