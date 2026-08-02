import SwiftUI

/// Popover navigation branch: the settings screen.
struct SettingsScreenView: View {
    let settings: AppSettings
    let onDismiss: () -> Void

    var body: some View {
        PopoverScreenScroll(displayMode: settings.displayMode) {
            SettingsView(settings: settings, onDismiss: onDismiss)
        }
    }
}

#Preview {
    SettingsScreenView(settings: AppSettings(), onDismiss: {})
}
