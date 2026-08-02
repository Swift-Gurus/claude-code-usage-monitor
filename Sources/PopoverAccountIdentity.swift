import Foundation

/// Resolves an account group's display name, preferring the matching Account's alias
/// over the group's own (possibly synthesized) name.
struct PopoverAccountIdentity {
    let group: PopoverAccountGroup
    let accounts: [Account]

    var matchedAccount: Account? {
        accounts.first { $0.id == group.accountID }
    }

    var displayName: String {
        matchedAccount?.displayName ?? group.accountName
    }
}
