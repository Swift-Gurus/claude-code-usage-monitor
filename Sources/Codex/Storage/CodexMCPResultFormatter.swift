import Foundation

/**
 solid-name: CodexMCPResultFormatter
 solid-category: service
 solid-description: Coordinates MCP completion outcome and duration formatting as display text.
 */
struct CodexMCPResultFormatter: CodexMCPResultFormatting {
    private let successFormatter: CodexMCPSuccessFormatting
    private let failureFormatter: CodexMCPFailureFormatting
    private let durationFormatter: CodexEventDurationFormatting

    init(
        successFormatter: CodexMCPSuccessFormatting = CodexMCPSuccessFormatter(),
        failureFormatter: CodexMCPFailureFormatting = CodexMCPFailureFormatter(),
        durationFormatter: CodexEventDurationFormatting = CodexEventDurationFormatter()
    ) {
        self.successFormatter = successFormatter
        self.failureFormatter = failureFormatter
        self.durationFormatter = durationFormatter
    }

    func format(payload: CodexRolloutPayload) -> String? {
        var parts: [String] = []
        if let success = payload.result?.success {
            parts.append(contentsOf: successFormatter.format(success))
        } else if let failure = payload.result?.failure {
            parts.append(contentsOf: failureFormatter.format(failure))
        }
        if let duration = durationFormatter.format(payload.duration) {
            parts.append(duration)
        }
        let result = parts.joined(separator: "\n\n")
        return result.isEmpty ? nil : result
    }
}
