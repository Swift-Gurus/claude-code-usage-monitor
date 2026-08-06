import Foundation

/**
 solid-name: CodexEventParser
 solid-category: service
 solid-description: Routes Codex event rollouts to focused handlers.
 */
struct CodexEventParser: CodexEventParsing {
    private let userHandler: CodexEventHandling
    private let reasoningHandler: CodexEventHandling
    private let errorHandler: CodexEventHandling
    private let tokenHandler: CodexEventHandling
    private let mcpCompletionHandler: CodexEventHandling
    private let resultHandler: CodexEventHandling
    private let genericHandler: CodexEventHandling

    init(
        userHandler: CodexEventHandling = CodexUserEventHandler(),
        reasoningHandler: CodexEventHandling = CodexReasoningEventHandler(),
        errorHandler: CodexEventHandling = CodexErrorEventHandler(),
        tokenHandler: CodexEventHandling = CodexTokenEventHandler(),
        mcpCompletionHandler: CodexEventHandling = CodexMCPCompletionEventHandler(),
        resultHandler: CodexEventHandling = CodexResultEventHandler(),
        genericHandler: CodexEventHandling = CodexGenericEventHandler()
    ) {
        self.userHandler = userHandler
        self.reasoningHandler = reasoningHandler
        self.errorHandler = errorHandler
        self.tokenHandler = tokenHandler
        self.mcpCompletionHandler = mcpCompletionHandler
        self.resultHandler = resultHandler
        self.genericHandler = genericHandler
    }

    func parse(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        switch rollout.payload.type {
        case "user_message":
            userHandler.handle(rollout, state: state)
        case "agent_reasoning":
            reasoningHandler.handle(rollout, state: state)
        case "error":
            errorHandler.handle(rollout, state: state)
        case "token_count":
            tokenHandler.handle(rollout, state: state)
        case "mcp_tool_call_end":
            mcpCompletionHandler.handle(rollout, state: state)
        case "exec_command_end", "patch_apply_end":
            resultHandler.handle(rollout, state: state)
        default:
            genericHandler.handle(rollout, state: state)
        }
    }
}
