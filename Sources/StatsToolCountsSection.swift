import SwiftUI

/// "Tool calls: N" header plus the sorted built-in tool breakdown.
struct StatsToolCountsSection: View {
    let tools: ToolCallStats

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerText
            StatsRowsList(entries: sortedByCountDescending(tools.countsByName))
        }
    }

    private var headerText: some View {
        Text("Tool calls: \(tools.total)").font(.caption).fontWeight(.medium)
    }
}

#Preview {
    StatsToolCountsSection(tools: ToolCallStats(countsByName: ["Bash": 3, "Read": 5]))
}
