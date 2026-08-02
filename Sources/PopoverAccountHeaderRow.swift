import SwiftUI

/// Shared account-icon + name + status badge + optional trailing count row, used by
/// both the plan usage card and the simple account header.
struct PopoverAccountHeaderRow: View {
    let displayName: String
    let badgeLabel: String
    let badgeColor: Color
    let trailingCount: Int

    var body: some View {
        HStack {
            leadingSection
            Spacer()
            countTextIfNeeded
        }
    }

    private var leadingSection: some View {
        HStack {
            accountIcon
            displayNameText
            HookStatusBadge(label: badgeLabel, color: badgeColor)
        }
    }

    private var accountIcon: some View {
        Image(systemName: "person.circle").font(.caption).foregroundStyle(.secondary)
    }

    private var displayNameText: some View {
        Text(displayName).font(.subheadline).fontWeight(.medium)
    }

    @ViewBuilder
    private var countTextIfNeeded: some View {
        if trailingCount > 0 {
            countText
        }
    }

    private var countText: some View {
        Text("\(trailingCount)").font(.caption).foregroundStyle(.secondary)
    }
}

#Preview {
    PopoverAccountHeaderRow(displayName: "Personal", badgeLabel: "Max 20x", badgeColor: .orange, trailingCount: 2)
}
