import SwiftUI

/// Small labeled value column, e.g. "Messages" / "12/day".
struct PopoverStatColumn: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            labelText
            valueText
        }
    }

    private var labelText: some View {
        Text(label).font(.system(size: 9)).foregroundStyle(.tertiary)
    }

    private var valueText: some View {
        Text(value).font(.caption2).fontWeight(.medium).foregroundStyle(valueColor)
    }
}

#Preview {
    PopoverStatColumn(label: "Messages", value: "12/day")
}
