import Foundation

/**
 solid-name: CodexMCPToolNameResolving
 solid-category: abstraction
 solid-description: Contract for resolving MCP invocation identity into a normalized tool name.
 */
protocol CodexMCPToolNameResolving {
    func name(for invocation: CodexMCPInvocation) -> String
}
