import SwiftUI

/**
 solid-name: PromptActionButton
 solid-category: view-component
 solid-description: A button component that displays a title and executes a provided action when tapped.
 */
struct PromptActionButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            titleText
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.small)
    }

    private var titleText: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }
}

#Preview {
    PromptActionButton(title: "Allow", tint: .green, action: {})
        .padding()
}
