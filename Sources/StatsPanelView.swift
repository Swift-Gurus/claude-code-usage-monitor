import SwiftUI

/**
 solid-name: StatsPanelView
 solid-category: view-component
 solid-stack: [swiftui]
 solid-description: Displays tool, MCP, and token statistics.
 */
struct StatsPanelView: View {
    let stats: SessionStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsToolCountsSection(tools: stats.tools)
            StatsMCPCountsSection(mcp: stats.mcp)
            StatsTokenTotalsView(tokens: stats.tokens)
        }
        .padding(10)
    }
}

#Preview {
    StatsPanelView(stats: SessionStats(
        tools: ToolCallStats(countsByName: ["Bash": 3, "Read": 5]),
        mcp: MCPCallStats(byServer: ["ide": MCPCallStats.ServerStats(countsByTool: ["getDiagnostics": 2], payloadBytesByTool: ["getDiagnostics": 400])]),
        tokens: SessionTokenStats(inputTokens: 1000, outputTokens: 500, cacheCreationTokens: 0, cacheReadTokens: 9000)
    ))
    .frame(width: 220, height: 320)
}
