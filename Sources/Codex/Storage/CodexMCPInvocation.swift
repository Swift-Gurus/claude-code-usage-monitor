import Foundation

/**
 solid-name: CodexMCPInvocation
 solid-category: model
 solid-description: Represents the server, tool, and arguments of a completed Codex MCP invocation.
 */
struct CodexMCPInvocation: Decodable {
    let server: String
    let tool: String
    let arguments: JSONValue?
}
