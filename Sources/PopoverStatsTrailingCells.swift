import SwiftUI

/// Lines-delta + cost trailing cells shared by every row in the source breakdown table.
struct PopoverStatsTrailingCells: View {
    let stats: SourceModelStats
    var costFont: Font = .caption
    var costWeight: Font.Weight = .medium

    var body: some View {
        HStack(spacing: 0) {
            LinesDeltaView(
                added: stats.linesAdded, removed: stats.linesRemoved, addedColor: .green, removedColor: .red,
                spacing: 0, addedMinWidth: 46, removedMinWidth: 40
            )
            PopoverCostCell(cost: stats.cost, font: costFont, weight: costWeight)
        }
    }
}

#Preview {
    PopoverStatsTrailingCells(stats: SourceModelStats(cost: 12.3, linesAdded: 400, linesRemoved: 100))
}
