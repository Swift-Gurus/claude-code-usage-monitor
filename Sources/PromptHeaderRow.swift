import SwiftUI

/**
 solid-name: PromptHeaderRow
 solid-category: view-component
 solid-description: Displays identifying information for a tool permission request.
 */
struct PromptHeaderRow: View {
    let tc: LogToolCall

    var body: some View {
        HStack(spacing: 6) {
            icon
            nameText
            summaryText
        }
    }

    private var icon: some View {
        Image(systemName: "lock.shield")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    private var nameText: some View {
        Text(tc.name)
            .font(.caption)
            .fontWeight(.medium)
    }

    private var summaryText: some View {
        Text(tc.data.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

#Preview {
    PromptHeaderRow(tc: LogToolCall(id: "1", name: "Bash", data: .bash(BashToolData(command: "ls", description: "", timeout: nil))))
}
