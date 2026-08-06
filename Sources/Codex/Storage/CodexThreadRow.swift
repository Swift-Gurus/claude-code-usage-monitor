import Foundation

/**
 solid-name: CodexThreadRow
 solid-category: model
 solid-description: Represents Codex conversation metadata and usage data.
 */
struct CodexThreadRow: Decodable {
    let id: String
    let title: String
    let cwd: String
    let updatedAt: Double
    let createdAt: Double
    let model: String
    let tokensUsed: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case cwd
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case model
        case tokensUsed = "tokens_used"
    }
}
