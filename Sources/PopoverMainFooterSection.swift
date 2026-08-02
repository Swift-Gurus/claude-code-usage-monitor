import SwiftUI

/// "Open Project" button, per-account statusline status rows, and the Quit button.
struct PopoverMainFooterSection: View {
    let accounts: [Account]
    let onOpenProject: () -> Void
    let onInstallStatusline: (Account) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PopoverOpenProjectButton(action: onOpenProject)
            Divider()
            PopoverStatuslineStatusRows(accounts: accounts, onInstall: onInstallStatusline)
            PopoverQuitButton()
        }
    }
}

#Preview {
    PopoverMainFooterSection(accounts: [.default], onOpenProject: {}, onInstallStatusline: { _ in })
}
