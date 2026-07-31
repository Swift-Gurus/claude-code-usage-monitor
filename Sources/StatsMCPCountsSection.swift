import SwiftUI

/// "MCP calls: N" header plus the sorted server/tool breakdown and the approximate
/// result-payload volume.
struct StatsMCPCountsSection: View {
    let mcp: MCPCallStats

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerText
            StatsRowsList(entries: SortedMCPCounts(byServer: mcp.byServer).entries)
            if mcp.approxPayloadTokens > 0 {
                payloadTokensText
            }
        }
    }

    private var headerText: some View {
        Text("MCP calls: \(mcp.total)").font(.caption).fontWeight(.medium)
    }

    private var payloadTokensText: some View {
        Text("~\(mcp.approxPayloadTokens) tokens returned").font(.caption2).foregroundStyle(.tertiary)
    }
}

#Preview {
    StatsMCPCountsSection(mcp: MCPCallStats(byServer: ["ide": MCPCallStats.ServerStats(countsByTool: ["getDiagnostics": 2], payloadBytesByTool: ["getDiagnostics": 400])]))
}
