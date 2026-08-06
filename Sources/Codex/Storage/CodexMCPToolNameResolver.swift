import Foundation

/**
 solid-name: CodexMCPToolNameResolver
 solid-category: utility
 solid-description: Resolves MCP invocation identity into a normalized tool name.
 */
struct CodexMCPToolNameResolver: CodexMCPToolNameResolving {
    func name(for invocation: CodexMCPInvocation) -> String {
        let server = invocation.server.replacingOccurrences(of: "-", with: "_")
        return "mcp__\(server)__\(invocation.tool)"
    }
}
