import SwiftUI

/**
 solid-name: MessageRoleHeaderView
 solid-category: view-component
 solid-description: Displays message role with an optional timestamp.
 */
struct MessageRoleHeaderView: View {
    let role: LogRole
    let roleLabel: String
    let timestamp: Date?

    var body: some View {
        HStack(spacing: 4) {
            dot
            label
            Spacer()
            if let timestamp { timestampText(timestamp) }
        }
    }

    private var dot: some View {
        StatusDot(color: role.dotColor)
            .frame(maxWidth: 6, maxHeight: 6)
    }

    private var label: some View {
        Text(roleLabel)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private func timestampText(_ ts: Date) -> some View {
        Text(ts, format: .dateTime.hour().minute().second())
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    MessageRoleHeaderView(role: .assistant, roleLabel: "Opus 4.6", timestamp: Date())
}
