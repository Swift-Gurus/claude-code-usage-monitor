import SwiftUI

/**
 solid-name: EmptyStateView
 solid-category: view-component
 solid-description: "Displays a customizable placeholder message when content is unavailable."
 */
struct EmptyStateView: View {
    var message: String = "No messages found"

    var body: some View {
        emptyStateText
    }

    private var emptyStateText: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 8)
    }
}

#Preview {
    EmptyStateView()
}