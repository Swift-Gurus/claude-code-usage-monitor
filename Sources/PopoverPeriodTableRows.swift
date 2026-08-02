import SwiftUI

/// Header + tappable data rows for the period cost table's Grid content.
struct PopoverPeriodTableRows: View {
    let rows: [(label: String, stats: PeriodStats)]
    let onSelect: (String) -> Void

    var body: some View {
        Group {
            PopoverPeriodTableHeader()
            dataRows
        }
    }

    private var dataRows: some View {
        ForEach(rows, id: \.label) { row in
            PopoverPeriodRow(label: row.label, stats: row.stats, onTap: { onSelect(row.label) })
        }
    }
}

#Preview {
    Grid(alignment: .trailing, verticalSpacing: 8) {
        PopoverPeriodTableRows(
            rows: [("Today", PeriodStats(cost: 4.5, linesAdded: 120, linesRemoved: 30))],
            onSelect: { _ in }
        )
    }
}
