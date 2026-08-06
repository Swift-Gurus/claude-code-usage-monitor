import Foundation

/**
 solid-name: CodexTextContentResolving
 solid-category: abstraction
 solid-description: Contract for resolving flexible Codex output values into display text.
 */
protocol CodexTextContentResolving {
    func text(from content: CodexTextContent?) -> String?
}
