import Foundation

/**
 solid-name: CodexToolCallParser
 solid-category: service
 solid-description: Translates Codex tool invocations into displayable tool calls.
 */
struct CodexToolCallParser: CodexToolCallParsing {
    private let toolDataParser: ToolDataParsing
    private let mcpToolNameExtractor: MCPToolNameExtracting

    init(
        toolDataParser: ToolDataParsing = ToolDataParser(),
        mcpToolNameExtractor: MCPToolNameExtracting = MCPToolNameExtractor()
    ) {
        self.toolDataParser = toolDataParser
        self.mcpToolNameExtractor = mcpToolNameExtractor
    }

    func toolCalls(
        for payload: CodexRolloutPayload,
        callID: String,
        input: [String: Any]
    ) -> [LogToolCall] {
        let nestedNames = mcpToolNameExtractor.names(in: payload.input)
        if nestedNames.count == 1, let name = nestedNames.first {
            return [makeToolCall(id: callID, name: name, input: [:])]
        }
        if !nestedNames.isEmpty {
            return nestedNames.enumerated().map { index, name in
                makeToolCall(id: "\(callID)-nested-\(index)", name: name, input: [:])
            }
        }

        return [makeToolCall(id: callID, name: normalizedToolName(for: payload), input: input)]
    }

    private func normalizedToolName(for payload: CodexRolloutPayload) -> String {
        let name = payload.name ?? "Tool"
        guard let namespace = payload.namespace, namespace.hasPrefix("mcp__") else {
            return name
        }
        return namespace.hasSuffix("__") ? namespace + name : namespace + "__" + name
    }

    private func makeToolCall(id: String, name: String, input: [String: Any]) -> LogToolCall {
        LogToolCall(
            id: id,
            name: name,
            data: toolDataParser.parseToolData(name: name, input: input)
        )
    }
}
