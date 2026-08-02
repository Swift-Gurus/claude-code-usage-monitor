import SwiftUI

/// The account Picker itself, without external label/font styling.
struct PopoverAccountPickerContent: View {
    let accounts: [Account]
    @Binding var selection: String

    var body: some View {
        Picker("Account", selection: $selection) {
            allAccountsOption
            PopoverAccountOptions(accounts: accounts)
        }
    }

    private var allAccountsOption: some View {
        Text("All Accounts").tag("all")
    }
}

#Preview {
    PopoverAccountPickerContent(accounts: [.default], selection: .constant("all"))
}
