import Foundation

/**
 solid-name: CodexRolloutEventRenderer
 solid-category: service
 solid-description: Renders Codex status, error, and generic rollout events as display text.
 */
struct CodexRolloutEventRenderer: CodexRolloutEventRendering {
    private let textNormalizer: OptionalTextNormalizing
    private let textContentResolver: CodexTextContentResolving

    init(
        textNormalizer: OptionalTextNormalizing = WhitespaceTextNormalizer(),
        textContentResolver: CodexTextContentResolving = CodexTextContentResolver()
    ) {
        self.textNormalizer = textNormalizer
        self.textContentResolver = textContentResolver
    }

    func resultText(from payload: CodexRolloutPayload) -> String? {
        var parts: [String] = []
        if let aggregatedOutput = textNormalizer.normalize(payload.aggregatedOutput) {
            parts.append(aggregatedOutput)
        } else if let standardOutput = textNormalizer.normalize(payload.stdout) {
            parts.append(standardOutput)
        }
        if let standardError = textNormalizer.normalize(payload.stderr) {
            parts.append(standardError)
        }
        if let success = payload.success {
            parts.append(success ? "status: completed" : "status: failed")
        }
        let joined = parts.joined(separator: "\n\n")
        return joined.isEmpty ? nil : joined
    }

    func errorText(from payload: CodexRolloutPayload) -> String? {
        textNormalizer.normalize(payload.message)
    }

    func genericText(from payload: CodexRolloutPayload) -> String? {
        guard let eventType = payload.type, !ignoredEventTypes.contains(eventType) else { return nil }
        let parts = [
            payload.message,
            textContentResolver.text(from: payload.output),
            payload.aggregatedOutput,
            payload.stdout,
            payload.stderr
        ].compactMap(textNormalizer.normalize)

        return parts.isEmpty
            ? eventType
            : eventType + "\n" + parts.joined(separator: "\n\n")
    }

    private var ignoredEventTypes: Set<String> {
        [
            "agent_message",
            "exec_command_end",
            "patch_apply_end",
            "task_complete",
            "task_started",
            "thread_name_updated",
            "token_count",
            "user_message"
        ]
    }
}
