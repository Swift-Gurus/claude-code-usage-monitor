import SwiftUI

/// Subagent rollup summary row plus per-model breakdown within a source.
struct PopoverSubagentsSection: View {
    let subagentsByModel: [String: SourceModelStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PopoverIndentedLabelRow(icon: "arrow.turn.down.right", label: "Subagents", stats: subagentsByModel.totalStats, indent: 8, topPadding: 2)
            PopoverModelRowsList(byModel: subagentsByModel, indent: 28, font: .caption2)
        }
    }
}

#Preview {
    PopoverSubagentsSection(subagentsByModel: ["claude-opus-4-6": SourceModelStats(cost: 2, linesAdded: 40, linesRemoved: 10)])
}
