import Foundation

/**
 solid-name: CodexMCPResult
 solid-category: model
 solid-description: Represents content blocks and error status returned by a Codex MCP invocation.
 */
struct CodexMCPResult: Decodable {
    let content: [CodexMessageContent]?
    let isError: Bool?
}
