import SwiftUI

/// "Quit" button at the bottom of the popover's main view.
struct PopoverQuitButton: View {
    var body: some View {
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .font(.caption)
    }
}

#Preview {
    PopoverQuitButton()
}
