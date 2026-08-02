import SwiftUI

/// Picker options for each account, tagged by UUID string.
struct PopoverAccountOptions: View {
    let accounts: [Account]

    var body: some View {
        ForEach(accounts) { account in
            optionText(account)
        }
    }

    private func optionText(_ account: Account) -> some View {
        Text(account.displayName).tag(account.id.uuidString)
    }
}

#Preview {
    PopoverAccountOptions(accounts: [.default])
}
