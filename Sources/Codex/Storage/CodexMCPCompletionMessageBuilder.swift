import Foundation

/**
 solid-name: CodexMCPCompletionMessageBuilder
 solid-category: service
 solid-description: Builds rich log messages from authoritative MCP completion events.
 */
struct CodexMCPCompletionMessageBuilder: CodexMCPCompletionMessageBuilding {
    private let toolNameResolver: CodexMCPToolNameResolving
    private let valueConverter: JSONValueDictionaryConverting
    private let toolDataParser: ToolDataParsing
    private let resultFormatter: CodexMCPResultFormatting

    init(
        toolNameResolver: CodexMCPToolNameResolving = CodexMCPToolNameResolver(),
        valueConverter: JSONValueDictionaryConverting = JSONValueDictionaryConverter(),
        toolDataParser: ToolDataParsing = ToolDataParser(),
        resultFormatter: CodexMCPResultFormatting = CodexMCPResultFormatter()
    ) {
        self.toolNameResolver = toolNameResolver
        self.valueConverter = valueConverter
        self.toolDataParser = toolDataParser
        self.resultFormatter = resultFormatter
    }

    func message(from rollout: CodexTimestampedRollout) -> LogMessage? {
        guard let invocation = rollout.payload.invocation else { return nil }
        let callID = rollout.payload.callID ?? "codex-mcp-call-\(rollout.offset)"
        let name = toolNameResolver.name(for: invocation)
        let input: [String: Any]
        if case .object(let values) = invocation.arguments {
            input = valueConverter.dictionary(from: values)
        } else {
            input = [:]
        }
        let resultContent = resultFormatter.format(payload: rollout.payload)

        return LogMessage(
            id: "codex-mcp-message-\(callID)",
            role: .assistant,
            model: nil,
            timestamp: rollout.timestamp,
            thinking: nil,
            textContent: [],
            toolCalls: [LogToolCall(
                id: callID,
                name: name,
                data: toolDataParser.parseToolData(name: name, input: input)
            )],
            toolResultIDs: [],
            toolResponses: [:],
            toolResultContents: resultContent.map { [callID: $0] } ?? [:]
        )
    }
}
