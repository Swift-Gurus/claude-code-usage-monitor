import Foundation

/**
 solid-name: CodexToolInputResolver
 solid-category: service
 solid-description: Resolves Codex tool payload text into input dictionary values.
 */
struct CodexToolInputResolver: CodexToolInputResolving {
    private let jsonDecoder: JSONDictionaryDecoding
    private let contentNormalizer: CodexEventContentNormalizing

    init(
        jsonDecoder: JSONDictionaryDecoding = JSONDictionaryDecoder(),
        contentNormalizer: CodexEventContentNormalizing = CodexEventContentNormalizer()
    ) {
        self.jsonDecoder = jsonDecoder
        self.contentNormalizer = contentNormalizer
    }

    func input(for payload: CodexRolloutPayload) -> [String: Any] {
        if let arguments = jsonDecoder.decode(payload.arguments) {
            return arguments
        }
        if let rawInput = contentNormalizer.text(payload.input) {
            return ["input": rawInput]
        }
        return [:]
    }
}
