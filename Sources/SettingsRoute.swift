import SwiftUI

/// Popover router branch for the settings screen.
struct SettingsRoute: View {
    let settings: AppSettings
    let navigation: PopoverNavigationState

    var body: some View {
        SettingsScreenView(settings: settings, onDismiss: navigation.closeSettings)
    }
}

#Preview {
    SettingsRoute(settings: AppSettings(), navigation: PopoverNavigationState())
}
