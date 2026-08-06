import Foundation

/**
 solid-name: CodexMCPSuccessFormatter
 solid-category: service
 solid-description: Formats successful MCP result content and status.
 */
struct CodexMCPSuccessFormatter: CodexMCPSuccessFormatting {
    private let textNormalizer: OptionalTextNormalizing

    init(textNormalizer: OptionalTextNormalizing = WhitespaceTextNormalizer()) {
        self.textNormalizer = textNormalizer
    }

    func format(_ result: CodexMCPResult) -> [String] {
        var parts = (result.content ?? []).compactMap(\.text).compactMap(textNormalizer.normalize)
        if let isError = result.isError {
            parts.append(isError ? "status: failed" : "status: completed")
        }
        return parts
    }
}
