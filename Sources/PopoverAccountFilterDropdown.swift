import SwiftUI

/// "All Accounts" / per-account picker for filtering the popover's cost breakdown.
struct PopoverAccountFilterDropdown: View {
    let accounts: [Account]
    @Binding var filterAccountID: UUID?

    private var selection: Binding<String> {
        Binding(
            get: { filterAccountID?.uuidString ?? "all" },
            set: { filterAccountID = $0 == "all" ? nil : UUID(uuidString: $0) }
        )
    }

    var body: some View {
        PopoverAccountPickerContent(accounts: accounts, selection: selection)
            .labelsHidden()
            .font(.caption)
    }
}

#Preview {
    PopoverAccountFilterDropdown(accounts: [.default], filterAccountID: .constant(nil))
}
