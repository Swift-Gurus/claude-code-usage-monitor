import Foundation

/**
 solid-name: CodexToolCallMessageIndexing
 solid-category: abstraction
 solid-description: Contract for recording parsed-message locations by Codex tool-call identifier.
 */
protocol CodexToolCallMessageIndexing: AnyObject {
    func recordMessageIndex(_ index: Int, for callID: String)
}
