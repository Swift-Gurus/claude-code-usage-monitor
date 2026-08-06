import Foundation

/**
 solid-name: CodexToolInputResolving
 solid-category: abstraction
 solid-description: Contract for resolving Codex tool payload text into input dictionary values.
 */
protocol CodexToolInputResolving {
    func input(for payload: CodexRolloutPayload) -> [String: Any]
}
