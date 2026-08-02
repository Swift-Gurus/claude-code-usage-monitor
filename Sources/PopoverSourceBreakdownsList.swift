import SwiftUI

/// One divider + breakdown per non-empty source (CLI/Commander).
struct PopoverSourceBreakdownsList: View {
    let sources: [(name: String, icon: String, source: SourceStats)]

    var body: some View {
        ForEach(sources, id: \.name) { item in
            Divider()
            PopoverSourceBreakdown(name: item.name, icon: item.icon, source: item.source)
        }
    }
}

#Preview {
    PopoverSourceBreakdownsList(sources: [
        ("CLI", "terminal", SourceStats(total: SourceModelStats(cost: 4, linesAdded: 100, linesRemoved: 20)))
    ])
}
