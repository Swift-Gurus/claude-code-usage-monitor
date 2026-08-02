import SwiftUI

/// Account icon, name, plan badge, and optional agent count for the plan usage card.
struct PopoverPlanUsageCardHeader: View {
    let displayName: String
    let planLabel: String
    let agentCount: Int

    var body: some View {
        PopoverAccountHeaderRow(displayName: displayName, badgeLabel: planLabel, badgeColor: .orange, trailingCount: agentCount)
    }
}

#Preview {
    PopoverPlanUsageCardHeader(displayName: "Personal", planLabel: "Max 20x", agentCount: 2)
}
