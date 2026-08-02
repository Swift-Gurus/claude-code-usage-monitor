import SwiftUI

/// "Open Project" button in the popover's main view.
struct PopoverOpenProjectButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OpenProjectButtonContent()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PopoverOpenProjectButton(action: {})
}
