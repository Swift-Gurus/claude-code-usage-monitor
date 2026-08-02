import SwiftUI

/// Source name (CLI/Commander) with icon and total cost/lines, heading a source breakdown.
struct PopoverSourceHeaderRow: View {
    let name: String
    let icon: String
    let stats: SourceModelStats

    var body: some View {
        HStack(spacing: 0) {
            leadingSection
            Spacer(minLength: 2)
            PopoverStatsTrailingCells(stats: stats, costFont: .subheadline, costWeight: .semibold)
        }
    }

    private var leadingSection: some View {
        HStack(spacing: 0) {
            iconView
            nameText
        }
    }

    private var iconView: some View {
        Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
    }

    private var nameText: some View {
        Text(" \(name)").font(.subheadline).fontWeight(.medium)
    }
}

#Preview {
    PopoverSourceHeaderRow(name: "CLI", icon: "terminal", stats: SourceModelStats(cost: 12.3, linesAdded: 400, linesRemoved: 100))
}
