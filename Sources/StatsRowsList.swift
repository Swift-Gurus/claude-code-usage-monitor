import SwiftUI

/// One StatsCountRow per already-sorted labeled count. Shared by the built-in tool and
/// MCP call breakdowns, which differ only in how their entries are produced.
struct StatsRowsList: View {
    let entries: [(label: String, count: Int)]

    var body: some View {
        ForEach(entries, id: \.label) { entry in
            StatsCountRow(name: entry.label, count: entry.count)
        }
    }
}

#Preview {
    StatsRowsList(entries: [(label: "Bash", count: 3), (label: "Read", count: 5)])
}
