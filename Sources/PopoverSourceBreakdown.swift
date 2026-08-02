import SwiftUI

/// Full cost/lines breakdown for one source (CLI or Commander): totals, per-model rows,
/// subagent rollup, and per-project rollup.
struct PopoverSourceBreakdown: View {
    let name: String
    let icon: String
    let source: SourceStats

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PopoverSourceBreakdownHeader(name: name, icon: icon, source: source)
            PopoverSourceBreakdownDetails(source: source)
        }
    }
}

#Preview {
    PopoverSourceBreakdown(
        name: "CLI", icon: "terminal",
        source: SourceStats(total: SourceModelStats(cost: 12.3, linesAdded: 400, linesRemoved: 100))
    )
}
