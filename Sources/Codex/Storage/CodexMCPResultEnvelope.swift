import Foundation

/**
 solid-name: CodexMCPResultEnvelope
 solid-category: model
 solid-description: Represents successful and failed operation completion outcomes with structured result data.
 */
struct CodexMCPResultEnvelope: Decodable {
    let success: CodexMCPResult?
    let failure: JSONValue?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodexMCPResultEnvelopeCodingKey.self)
        self.success = try container.decodeIfPresent(CodexMCPResult.self, forKey: .success)
        self.failure = try container.decodeIfPresent(JSONValue.self, forKey: .failure)
    }
}
