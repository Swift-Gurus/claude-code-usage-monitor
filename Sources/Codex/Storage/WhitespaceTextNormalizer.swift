import Foundation

/**
 solid-name: WhitespaceTextNormalizer
 solid-category: utility
 solid-description: Trims optional text and rejects values containing only whitespace.
 */
struct WhitespaceTextNormalizer: OptionalTextNormalizing {
    func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
