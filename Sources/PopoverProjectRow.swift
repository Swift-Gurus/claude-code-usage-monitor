import SwiftUI

/// One project's cost/lines row (main + subagents combined), with an optional nested
/// subagent-only breakdown line.
struct PopoverProjectRow: View {
    let projectName: String
    let stats: ProjectStats

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PopoverIndentedLabelRow(icon: "folder", label: projectName, stats: stats.total, indent: 8)
            PopoverProjectSubagentsRow(stats: stats)
        }
    }
}

#Preview {
    PopoverProjectRow(
        projectName: "my-app",
        stats: ProjectStats(main: SourceModelStats(cost: 10, linesAdded: 200, linesRemoved: 50), subagents: SourceModelStats(cost: 2, linesAdded: 40, linesRemoved: 10))
    )
}
