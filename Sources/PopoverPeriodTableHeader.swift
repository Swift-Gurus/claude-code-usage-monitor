import SwiftUI

/// Column headers for the period cost table: Cost / +Lines / -Lines.
struct PopoverPeriodTableHeader: View {
    var body: some View {
        GridRow {
            leadingSpacer
            costHeader
            addedHeader
            removedHeader
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var leadingSpacer: some View {
        Spacer().gridColumnAlignment(.leading)
    }

    private var costHeader: some View {
        Text("Cost")
    }

    private var addedHeader: some View {
        Text("+Lines")
    }

    private var removedHeader: some View {
        Text("-Lines")
    }
}

#Preview {
    Grid {
        PopoverPeriodTableHeader()
    }
}
