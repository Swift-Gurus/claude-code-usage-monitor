import Foundation

/**
 solid-name: MCPToolNameExtracting
 solid-category: abstraction
 solid-description: Contract for identifying MCP tool names embedded in invocation text.
 */
protocol MCPToolNameExtracting {
    func names(in source: String?) -> [String]
}
