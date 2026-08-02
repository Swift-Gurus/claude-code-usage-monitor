import SwiftUI

/// Source totals row plus its per-model breakdown (or a fallback note when unavailable).
struct PopoverSourceBreakdownHeader: View {
    let name: String
    let icon: String
    let source: SourceStats

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PopoverSourceHeaderRow(name: name, icon: icon, stats: source.total)
            PopoverModelRowsList(byModel: source.byModel)
            noModelBreakdownNoteIfNeeded
        }
    }

    @ViewBuilder
    private var noModelBreakdownNoteIfNeeded: some View {
        if source.byModel.isEmpty && source.total.cost > 0 {
            noModelBreakdownText
        }
    }

    private var noModelBreakdownText: some View {
        Text("Model breakdown not available for older sessions")
            .font(.caption2).foregroundStyle(.tertiary)
            .padding(.leading, 20)
    }
}

#Preview {
    PopoverSourceBreakdownHeader(
        name: "CLI", icon: "terminal",
        source: SourceStats(total: SourceModelStats(cost: 12.3, linesAdded: 400, linesRemoved: 100))
    )
}
