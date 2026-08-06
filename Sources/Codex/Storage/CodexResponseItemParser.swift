import Foundation

/**
 solid-name: CodexResponseItemParser
 solid-category: service
 solid-description: Routes Codex response-item rollouts to focused handlers.
 */
struct CodexResponseItemParser: CodexResponseItemParsing {
    private let messageHandler: CodexResponseItemHandling
    private let reasoningHandler: CodexResponseItemHandling
    private let invocationHandler: CodexResponseItemHandling
    private let outputHandler: CodexResponseItemHandling

    init(
        messageHandler: CodexResponseItemHandling = CodexResponseMessageHandler(),
        reasoningHandler: CodexResponseItemHandling = CodexReasoningResponseHandler(),
        invocationHandler: CodexResponseItemHandling = CodexToolInvocationHandler(),
        outputHandler: CodexResponseItemHandling = CodexToolOutputHandler()
    ) {
        self.messageHandler = messageHandler
        self.reasoningHandler = reasoningHandler
        self.invocationHandler = invocationHandler
        self.outputHandler = outputHandler
    }

    func parse(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        switch rollout.payload.type {
        case "message":
            messageHandler.handle(rollout, state: state)
        case "reasoning":
            reasoningHandler.handle(rollout, state: state)
        case "function_call", "custom_tool_call":
            invocationHandler.handle(rollout, state: state)
        case "function_call_output", "custom_tool_call_output":
            outputHandler.handle(rollout, state: state)
        default:
            return
        }
    }
}
