import SwiftUI

/// Today/This Week/This Month cost columns for the plan usage card.
struct PopoverAccountCostSummary: View {
    let stats: AccountPeriodStats

    var body: some View {
        HStack(spacing: 12) {
            PopoverStatColumn(label: "Today", value: stats.day.cost.asCostString, valueColor: .orange)
            PopoverStatColumn(label: "This Week", value: stats.week.cost.asCostString, valueColor: .orange)
            PopoverStatColumn(label: "This Month", value: stats.month.cost.asCostString, valueColor: .orange)
            Spacer()
        }
    }
}

#Preview {
    PopoverAccountCostSummary(stats: AccountPeriodStats())
}
