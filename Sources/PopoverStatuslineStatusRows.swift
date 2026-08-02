import SwiftUI

/// One statusline status row per account.
struct PopoverStatuslineStatusRows: View {
    let accounts: [Account]
    var installChecker: StatuslineInstallationChecking = DefaultStatuslineInstallationChecker()
    let onInstall: (Account) -> Void

    var body: some View {
        ForEach(accounts) { account in
            PopoverStatuslineStatusRow(
                account: account, isInstalled: installChecker.isInstalled(claudeDir: account.claudeDir),
                onInstall: { onInstall(account) }
            )
        }
    }
}

#Preview {
    PopoverStatuslineStatusRows(accounts: [.default], onInstall: { _ in })
}
