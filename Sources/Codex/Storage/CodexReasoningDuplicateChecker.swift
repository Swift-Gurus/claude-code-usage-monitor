import Foundation

/**
 solid-name: CodexReasoningDuplicateChecker
 solid-category: service
 solid-description: Detects reasoning text already represented by nearby Codex messages.
 */
struct CodexReasoningDuplicateChecker: CodexReasoningDuplicateChecking {
    private let textNormalizer: OptionalTextNormalizing
    private let timestampTolerance: TimeInterval

    init(
        textNormalizer: OptionalTextNormalizing = WhitespaceTextNormalizer(),
        timestampTolerance: TimeInterval = 1
    ) {
        self.textNormalizer = textNormalizer
        self.timestampTolerance = timestampTolerance
    }

    func isDuplicate(text: String, timestamp: Date?, messages: [LogMessage]) -> Bool {
        guard let timestamp else { return false }
        let nearbyReasoning = messages.compactMap { message -> String? in
            guard let messageTimestamp = message.timestamp,
                  abs(messageTimestamp.timeIntervalSince(timestamp)) <= timestampTolerance
            else { return nil }
            return message.thinking
        }
        if nearbyReasoning.contains(text) {
            return true
        }

        let summaryLines = text
            .split(separator: "\n")
            .compactMap { textNormalizer.normalize(String($0)) }
        return !summaryLines.isEmpty && summaryLines.allSatisfy { line in
            nearbyReasoning.contains { $0 == line || $0.contains(line) || line.contains($0) }
        }
    }
}
