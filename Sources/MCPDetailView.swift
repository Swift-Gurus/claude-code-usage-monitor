import SwiftUI

/**
 solid-name: MCPDetailView
 solid-category: view-component
 solid-description: Displays the server, tool name, input parameters, and optional result of an MCP tool call.
 */
struct MCPDetailView: View {
    let data: MCPToolData
    let resultContent: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MCPNameHeader(serverName: data.serverName, toolName: data.toolName)
            inputIfPresent
            resultIfPresent
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var inputIfPresent: some View {
        if !data.input.isEmpty {
            MonoTextView(text: data.input.formattedKeyValuePairs())
        }
    }

    @ViewBuilder
    private var resultIfPresent: some View {
        if let result = resultContent, !result.isEmpty {
            ToolResultView(content: result)
        }
    }
}

#Preview {
    MCPDetailView(data: MCPToolData(serverName: "ide", toolName: "getDiagnostics", input: [:]), resultContent: nil)
        .padding()
}
