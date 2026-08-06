import Foundation

/**
 solid-name: CodexUserMessageDuplicateChecker
 solid-category: service
 solid-description: Detects mirrored Codex user messages by text and timestamp.
 */
struct CodexUserMessageDuplicateChecker: CodexUserMessageDuplicateChecking {
    private let textNormalizer: OptionalTextNormalizing

    init(textNormalizer: OptionalTextNormalizing = WhitespaceTextNormalizer()) {
        self.textNormalizer = textNormalizer
    }

    func isDuplicate(text: String, timestamp: Date?, messages: [LogMessage]) -> Bool {
        guard let timestamp, let normalizedText = textNormalizer.normalize(text) else { return false }
        return messages.contains {
            $0.role == .user
                && $0.timestamp == timestamp
                && $0.textContent.contains {
                    textNormalizer.normalize($0) == normalizedText
                }
        }
    }
}
