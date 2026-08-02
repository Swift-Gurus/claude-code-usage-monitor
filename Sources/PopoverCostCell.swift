import SwiftUI

/// Fixed-width, trailing-aligned cost cell for the source breakdown table.
struct PopoverCostCell: View {
    let cost: Double
    var font: Font = .caption
    var weight: Font.Weight = .medium

    var body: some View {
        costText
    }

    private var costText: some View {
        Text(cost.asCostString)
            .font(font)
            .fontWeight(weight)
            .foregroundStyle(.orange)
            .frame(minWidth: 64, alignment: .trailing)
    }
}

#Preview {
    PopoverCostCell(cost: 12.34)
}
