import SwiftUI

/// Nested subagent-only cost/lines row for a project, shown only when there's a
/// non-zero subagent cost.
struct PopoverProjectSubagentsRow: View {
    let stats: ProjectStats

    var body: some View {
        if stats.subagents.cost > 0 {
            PopoverIndentedLabelRow(icon: "arrow.turn.down.right", label: "Subs", stats: stats.subagents, indent: 20)
        }
    }
}

#Preview {
    PopoverProjectSubagentsRow(
        stats: ProjectStats(main: SourceModelStats(cost: 10, linesAdded: 200, linesRemoved: 50), subagents: SourceModelStats(cost: 2, linesAdded: 40, linesRemoved: 10))
    )
}
