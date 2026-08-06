import Foundation

/**
 solid-name: CodexLogParseState
 solid-category: model
 solid-description: Groups independent message, tool-call index, and token-usage state collaborators for one Codex parse.
 */
struct CodexLogParseState {
    let messages: CodexMessageRetaining & CodexMessageReplacing
    let toolCalls: CodexToolCallMessageIndexing & CodexToolCallMessageLocating
    let tokens: CodexTokenUsageStateAccessing
    let mcpCompletions: CodexMCPCompletionTracking

    init(
        messages: CodexMessageRetaining & CodexMessageReplacing = CodexMessageStore(),
        toolCalls: CodexToolCallMessageIndexing & CodexToolCallMessageLocating = CodexToolCallMessageIndex(),
        tokens: CodexTokenUsageStateAccessing = CodexTokenUsageState(),
        mcpCompletions: CodexMCPCompletionTracking = CodexMCPCompletionTracker(countsByToolName: [:])
    ) {
        self.messages = messages
        self.toolCalls = toolCalls
        self.tokens = tokens
        self.mcpCompletions = mcpCompletions
    }
}
