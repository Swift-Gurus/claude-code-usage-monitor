import Foundation

/**
 solid-name: CodexRolloutEventRendering
 solid-category: abstraction
 solid-description: Contract for rendering Codex status, error, and generic rollout events as display text.
 */
protocol CodexRolloutEventRendering {
    func resultText(from payload: CodexRolloutPayload) -> String?
    func errorText(from payload: CodexRolloutPayload) -> String?
    func genericText(from payload: CodexRolloutPayload) -> String?
}
