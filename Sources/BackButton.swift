import SwiftUI

/// Shared chevron-left "Back" button, used across screens that dismiss to a previous view.
struct BackButton: View {
    let font: Font
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }

    private var label: some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
            Text("Back")
        }
        .font(font)
    }
}

#Preview {
    BackButton(font: .caption, action: {})
}
