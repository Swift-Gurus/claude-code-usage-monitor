import SwiftUI

/// Per-model rows for a source or subagent breakdown, sorted by cost descending.
struct PopoverModelRowsList: View {
    let byModel: [String: SourceModelStats]
    var indent: CGFloat = 20
    var font: Font = .caption

    var body: some View {
        ForEach(byModel.sortedByDescendingCost, id: \.key) { model, stats in
            PopoverModelRow(modelName: model, stats: stats, indent: indent, font: font)
        }
    }
}

#Preview {
    PopoverModelRowsList(byModel: ["claude-opus-4-6": SourceModelStats(cost: 4, linesAdded: 100, linesRemoved: 20)])
}
