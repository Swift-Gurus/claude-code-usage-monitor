import SwiftUI

/// One line in a stats breakdown list: a name on the left, its count right-aligned.
struct StatsCountRow: View {
    let name: String
    let count: Int

    var body: some View {
        HStack {
            labelText
            Spacer(minLength: 8)
            countText
        }
    }

    private var labelText: some View {
        Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
    }

    private var countText: some View {
        Text("\(count)").font(.caption).monospacedDigit()
    }
}

#Preview {
    StatsCountRow(name: "Bash", count: 3)
}
