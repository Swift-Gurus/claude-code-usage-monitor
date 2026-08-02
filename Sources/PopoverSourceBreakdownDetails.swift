import SwiftUI

/// Subagent rollup and per-project rollup sections of a source breakdown, each shown
/// only when there's data.
struct PopoverSourceBreakdownDetails: View {
    let source: SourceStats

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            subagentsSectionIfNeeded
            projectsSectionIfNeeded
        }
    }

    @ViewBuilder
    private var subagentsSectionIfNeeded: some View {
        if !source.subagentsByModel.isEmpty {
            PopoverSubagentsSection(subagentsByModel: source.subagentsByModel)
        }
    }

    @ViewBuilder
    private var projectsSectionIfNeeded: some View {
        if !source.byProject.isEmpty {
            PopoverProjectsSection(projects: source.byProject.sortedByDescendingCost)
        }
    }
}

#Preview {
    PopoverSourceBreakdownDetails(source: SourceStats())
}
