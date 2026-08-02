import SwiftUI

/**
 solid-name: LoadingStateView
 solid-category: view-component
 solid-description: Displays a loading state with customizable text.
 */
struct LoadingStateView: View {
    var message: String = "Loading logs..."

    var body: some View {
        LoadingIndicatorRow(message: message)
            .padding(.vertical, 20)
    }
}

#Preview {
    LoadingStateView()
}
