import Foundation

/**
 solid-name: CodexStateThread
 solid-category: model
 solid-description: Represents indexed Codex thread state used to build session summaries.
 */
struct CodexStateThread {
    let id: String
    let title: String
    let cwd: String
    let model: String
    let updatedAt: Date
    let createdAt: Date
    let tokensUsed: Int
}
