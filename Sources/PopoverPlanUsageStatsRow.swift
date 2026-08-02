import SwiftUI

/// Messages/day, output tokens, and session count columns for the plan usage card.
struct PopoverPlanUsageStatsRow: View {
    let avgMessagesPerDay: Double
    let outputTokens: Int
    let totalSessions: Int

    var body: some View {
        HStack(spacing: 12) {
            PopoverStatColumn(label: "Messages", value: String(format: "%.0f/day", avgMessagesPerDay))
            PopoverStatColumn(label: "Output Tokens", value: outputTokens.asTokenCountString)
            PopoverStatColumn(label: "Sessions", value: "\(totalSessions)")
            Spacer()
        }
    }
}

#Preview {
    PopoverPlanUsageStatsRow(avgMessagesPerDay: 12, outputTokens: 45_000, totalSessions: 8)
}
