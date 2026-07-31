import SwiftUI

/// Input/output/cache-creation/cache-read rows for a token totals breakdown.
struct StatsTokenRows: View {
    let tokens: SessionTokenStats

    var body: some View {
        Group {
            StatsCountRow(name: "Input", count: tokens.inputTokens)
            StatsCountRow(name: "Output", count: tokens.outputTokens)
            StatsCountRow(name: "Cache write", count: tokens.cacheCreationTokens)
            StatsCountRow(name: "Cache read", count: tokens.cacheReadTokens)
        }
    }
}

#Preview {
    StatsTokenRows(tokens: SessionTokenStats(inputTokens: 1000, outputTokens: 500, cacheCreationTokens: 0, cacheReadTokens: 9000))
}
