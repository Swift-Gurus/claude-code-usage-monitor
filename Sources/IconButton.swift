import SwiftUI

/**
 solid-name: IconButton
 solid-category: view-component
 solid-description: A configurable button component that displays an icon and executes a provided action.
 */
struct IconButton: View {
    let systemName: String
    let color: Color
    let font: Font
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(font)
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .help(help)
    }
}

#Preview {
    IconButton(systemName: "stop.circle.fill", color: .red, font: .caption, help: "Stop", action: {})
}
