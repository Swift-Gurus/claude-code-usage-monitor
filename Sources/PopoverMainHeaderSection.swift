import SwiftUI

/// Title/settings header plus optional account filter dropdown.
struct PopoverMainHeaderSection: View {
    let accounts: [Account]
    @Binding var filterAccountID: UUID?
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PopoverMainHeader(onOpenSettings: onOpenSettings)
            Divider()
            filterIfNeeded
        }
    }

    @ViewBuilder
    private var filterIfNeeded: some View {
        if accounts.count > 1 {
            PopoverAccountFilterDropdown(accounts: accounts, filterAccountID: $filterAccountID)
        }
    }
}

#Preview {
    PopoverMainHeaderSection(accounts: [.default], filterAccountID: .constant(nil), onOpenSettings: {})
}
