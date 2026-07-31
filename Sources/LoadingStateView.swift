import SwiftUI

/**
 solid-name: LoadingStateView
 solid-category: view-component
 solid-description: Displays a loading state indicator.
 */
struct LoadingStateView: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            loadingText
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var loadingText: some View {
        Text("Loading logs...")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    LoadingStateView()
}
