import SwiftUI

/// One model's cost/lines row within a source breakdown, at a caller-specified indent.
struct PopoverModelRow: View {
    let modelName: String
    let stats: SourceModelStats
    var indent: CGFloat = 20
    var font: Font = .caption

    var body: some View {
        HStack(spacing: 0) {
            nameText
            Spacer(minLength: 2)
            PopoverStatsTrailingCells(stats: stats)
        }
        .padding(.leading, indent)
    }

    private var nameText: some View {
        Text(modelName).font(font).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
    }
}

#Preview {
    PopoverModelRow(modelName: "claude-opus-4-6", stats: SourceModelStats(cost: 1.2, linesAdded: 40, linesRemoved: 10))
}
