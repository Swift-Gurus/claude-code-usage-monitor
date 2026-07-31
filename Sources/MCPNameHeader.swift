import SwiftUI

/**
 solid-name: MCPNameHeader
 solid-category: view-component
 solid-description: Renders a header with server and tool identifiers.
 */
struct MCPNameHeader: View {
    let serverName: String
    let toolName: String

    var body: some View {
        HStack(spacing: 4) {
            serverText
            separator
            toolText
        }
    }

    private var serverText: some View {
        Text(serverName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.cyan)
    }

    private var separator: some View {
        Text("·")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
    }

    private var toolText: some View {
        Text(toolName)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    MCPNameHeader(serverName: "ide", toolName: "getDiagnostics")
}
