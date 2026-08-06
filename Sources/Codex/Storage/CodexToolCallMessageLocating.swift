import Foundation

/**
 solid-name: CodexToolCallMessageLocating
 solid-category: abstraction
 solid-description: Contract for locating parsed-message indexes by Codex tool-call identifier.
 */
protocol CodexToolCallMessageLocating: AnyObject {
    func messageIndex(for callID: String) -> Int?
}
