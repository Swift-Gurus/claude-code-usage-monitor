import SwiftUI

/**
 solid-name: EmptyStateView
 solid-category: view-component
 solid-description: "Displays an empty state placeholder when no messages are available."
 */
struct EmptyStateView: View {
    var body: some View {
        Text("No messages found")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 8)
    }
}

#Preview {
    EmptyStateView()
}
