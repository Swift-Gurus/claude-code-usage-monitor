import SwiftUI

/// Title + settings gear button for the popover's main view.
struct PopoverMainHeader: View {
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            titleText
            Spacer()
            settingsButton
        }
    }

    private var titleText: some View {
        Text("Claude Usage").font(.headline)
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PopoverMainHeader(onOpenSettings: {})
}
