import SwiftUI

/// Cost + lines-added/removed summary row for a single reporting period.
struct CostLinesSummaryView: View {
    let stats: PeriodStats

    var body: some View {
        HStack {
            costText
            Spacer()
            LinesDeltaView(added: stats.linesAdded, removed: stats.linesRemoved, addedColor: .green, removedColor: .red)
        }
        .font(.caption)
    }

    private var costText: some View {
        Text(stats.cost.asCostString).font(.title3).fontWeight(.semibold).foregroundStyle(.orange)
    }
}

#Preview {
    CostLinesSummaryView(stats: PeriodStats(cost: 12.34, linesAdded: 120, linesRemoved: 40))
}
