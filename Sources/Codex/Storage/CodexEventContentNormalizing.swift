import Foundation

/**
 solid-name: CodexEventContentNormalizing
 solid-category: abstraction
 solid-description: Contract for normalizing display text from Codex event and result payloads.
 */
protocol CodexEventContentNormalizing {
    func text(_ value: String?) -> String?
    func toolResult(from rawValue: String?, decodedObject: [String: Any]?) -> String?
    func eventResult(from payload: CodexRolloutPayload) -> String?
    func errorText(from payload: CodexRolloutPayload) -> String?
    func genericEventText(from payload: CodexRolloutPayload) -> String?
}
