import SwiftUI

/// The progress spinner + message row shown by `LoadingStateView`, left-aligned within
/// whatever width its parent gives it (no `Spacer()`-driven expansion).
struct LoadingIndicatorRow: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            styledMessage
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var styledMessage: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    LoadingIndicatorRow(message: "Loading active agents...")
        .padding()
}
