import Foundation

/**
 solid-name: CodexToolCallMessageIndex
 solid-category: service
 solid-description: Records and locates parsed-message indexes by Codex tool-call identifier.
 */
final class CodexToolCallMessageIndex: CodexToolCallMessageIndexing, CodexToolCallMessageLocating {
    private var indexesByCallID: [String: Int] = [:]

    func recordMessageIndex(_ index: Int, for callID: String) {
        indexesByCallID[callID] = index
    }

    func messageIndex(for callID: String) -> Int? {
        indexesByCallID[callID]
    }
}
