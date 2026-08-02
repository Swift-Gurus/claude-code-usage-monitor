import SwiftUI

/// The four grid cells (label, cost, +lines, -lines) for one period row.
struct PopoverPeriodRowContent: View {
    let label: String
    let stats: PeriodStats

    var body: some View {
        GridRow {
            labelCell
            costText
            addedText
            removedText
        }
    }

    private var labelCell: some View {
        HStack(spacing: 4) {
            labelText
            chevronIcon
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var labelText: some View {
        Text(label).font(.subheadline).fontWeight(.medium)
    }

    private var chevronIcon: some View {
        Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(.tertiary)
    }

    private var costText: some View {
        Text(stats.cost.asCostString).font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
    }

    private var addedText: some View {
        Text("+\(stats.linesAdded.formatted(.number.notation(.compactName)))")
            .font(.caption)
            .foregroundStyle(.green)
    }

    private var removedText: some View {
        Text("-\(stats.linesRemoved.formatted(.number.notation(.compactName)))")
            .font(.caption)
            .foregroundStyle(.red)
    }
}

#Preview {
    Grid {
        PopoverPeriodRowContent(label: "Today", stats: PeriodStats(cost: 4.5, linesAdded: 120, linesRemoved: 30))
    }
}
