import Foundation

/**
 solid-name: CodexResponseMessageHandler
 solid-category: service
 solid-description: Converts Codex response messages into retained log messages.
 */
struct CodexResponseMessageHandler: CodexResponseItemHandling {
    private let roleResolver: CodexMessageRoleResolving

    init(roleResolver: CodexMessageRoleResolving = CodexMessageRoleResolver()) {
        self.roleResolver = roleResolver
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        let textContent = (rollout.payload.content ?? []).compactMap(\.text).filter { !$0.isEmpty }
        guard !textContent.isEmpty else { return }

        state.messages.appendMessage(LogMessage(
            id: "codex-message-\(rollout.offset)",
            role: roleResolver.role(rawRole: rollout.payload.role, textContent: textContent),
            model: nil,
            timestamp: rollout.timestamp,
            thinking: nil,
            textContent: textContent,
            toolCalls: [],
            toolResultIDs: [],
            toolResponses: [:],
            toolResultContents: [:]
        ))
    }

}
