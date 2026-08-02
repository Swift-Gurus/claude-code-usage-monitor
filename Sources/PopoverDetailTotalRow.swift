import SwiftUI

/// "Total" cost summary row on the period breakdown detail screen.
struct PopoverDetailTotalRow: View {
    let cost: Double

    var body: some View {
        HStack {
            totalLabel
            Spacer()
            costText
        }
    }

    private var totalLabel: some View {
        Text("Total").font(.subheadline).fontWeight(.medium)
    }

    private var costText: some View {
        Text(cost.asCostString).font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
    }
}

#Preview {
    PopoverDetailTotalRow(cost: 12.34)
}
