import Foundation

/**
 solid-name: CodexToolCallMessageRecorder
 solid-category: service
 solid-description: Records Codex tool invocations as indexed log messages.
 */
struct CodexToolCallMessageRecorder: CodexToolCallMessageRecording {
    private let toolCallParser: CodexToolCallParsing
    private let callCanonicalizer: CodexToolCallCanonicalizing

    init(
        toolCallParser: CodexToolCallParsing = CodexToolCallParser(),
        callCanonicalizer: CodexToolCallCanonicalizing = CodexToolCallCanonicalizer()
    ) {
        self.toolCallParser = toolCallParser
        self.callCanonicalizer = callCanonicalizer
    }

    func record(
        _ rollout: CodexTimestampedRollout,
        input: [String: Any],
        state: CodexLogParseState
    ) {
        let payload = rollout.payload
        let callID = payload.callID ?? "codex-call-\(rollout.offset)"
        let parsedCalls = toolCallParser.toolCalls(for: payload, callID: callID, input: input)
        let toolCalls = callCanonicalizer.canonicalCalls(
            from: parsedCalls,
            completions: state.mcpCompletions
        )
        guard !toolCalls.isEmpty else { return }

        state.toolCalls.recordMessageIndex(state.messages.parsedMessages.count, for: callID)
        state.messages.appendMessage(LogMessage(
            id: "codex-call-message-\(callID)",
            role: .assistant,
            model: nil,
            timestamp: rollout.timestamp,
            thinking: nil,
            textContent: [],
            toolCalls: toolCalls,
            toolResultIDs: [],
            toolResponses: [:],
            toolResultContents: [:]
        ))
    }
}
