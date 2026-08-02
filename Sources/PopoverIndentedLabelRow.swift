import SwiftUI

/// Icon + label + cost/lines row at a caller-specified indent, used for the subagents
/// summary and project rows within a source breakdown.
struct PopoverIndentedLabelRow: View {
    let icon: String
    let label: String
    let stats: SourceModelStats
    var indent: CGFloat = 8
    var topPadding: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            leadingSection
            Spacer(minLength: 2)
            PopoverStatsTrailingCells(stats: stats)
        }
        .padding(.leading, indent)
        .padding(.top, topPadding)
    }

    private var leadingSection: some View {
        HStack(spacing: 0) {
            iconView
            labelText
        }
    }

    private var iconView: some View {
        Image(systemName: icon).font(.caption2).foregroundStyle(.secondary)
    }

    private var labelText: some View {
        Text(" \(label)").font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
    }
}

#Preview {
    PopoverIndentedLabelRow(icon: "arrow.turn.down.right", label: "Subagents", stats: SourceModelStats(cost: 1.5, linesAdded: 50, linesRemoved: 10))
}
