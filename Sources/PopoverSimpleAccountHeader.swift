import SwiftUI

/// Compact account header for accounts without plan/rate-limit data.
struct PopoverSimpleAccountHeader: View {
    let displayName: String
    let accountTypeLabel: String
    let totalCount: Int

    var body: some View {
        PopoverAccountHeaderRow(displayName: displayName, badgeLabel: accountTypeLabel, badgeColor: .blue, trailingCount: totalCount)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.blue.opacity(0.1), lineWidth: 1))
    }
}

#Preview {
    PopoverSimpleAccountHeader(displayName: "Work", accountTypeLabel: "Enterprise", totalCount: 3)
}
