import SwiftUI

/// Token totals header + breakdown rows plus the resulting cache-hit rate.
struct StatsTokenTotalsView: View {
    let tokens: SessionTokenStats

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerText
            StatsTokenRows(tokens: tokens)
            cacheHitRateText
        }
    }

    private var headerText: some View {
        Text("Tokens").font(.caption).fontWeight(.medium)
    }

    private var cacheHitRateText: some View {
        Text("Cache hit rate: \(tokens.cacheHitRatePercent)%")
            .font(.caption2).foregroundStyle(.tertiary)
    }
}

#Preview {
    StatsTokenTotalsView(tokens: SessionTokenStats(inputTokens: 1000, outputTokens: 500, cacheCreationTokens: 0, cacheReadTokens: 9000))
}
