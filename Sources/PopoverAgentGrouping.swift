import Foundation

/// Groups working/idle agents by account, in `accounts` order, then appends any agents
/// whose accountID doesn't match a known account (inferring a plan type from whether
/// they carry live rate-limit data).
struct PopoverAgentGrouping {
    let accounts: [Account]
    let workingAgents: [AgentInfo]
    let idleAgents: [AgentInfo]

    var groups: [PopoverAccountGroup] {
        knownAccountGroups + unknownAccountGroups
    }

    private var knownAccountGroups: [PopoverAccountGroup] {
        accounts.compactMap { account in
            let active = workingAgents.filter { $0.accountID == account.id }
            let idle = idleAgents.filter { $0.accountID == account.id }
            guard !active.isEmpty || !idle.isEmpty else { return nil }
            return PopoverAccountGroup(
                accountID: account.id, accountName: account.displayName, accountType: account.accountType,
                active: active, idle: idle
            )
        }
    }

    private var unknownAccountGroups: [PopoverAccountGroup] {
        let knownIDs = Set(accounts.map(\.id))
        let unknownActive = workingAgents.filter { !knownIDs.contains($0.accountID) }
        let unknownIdle = idleAgents.filter { !knownIDs.contains($0.accountID) }
        let unknownIDs = Set(unknownActive.map(\.accountID) + unknownIdle.map(\.accountID))

        return unknownIDs.compactMap { accountID in
            let active = unknownActive.filter { $0.accountID == accountID }
            let idle = unknownIdle.filter { $0.accountID == accountID }
            guard let sample = (active + idle).first else { return nil }
            let inferredType: AccountType = (active + idle).contains { $0.rateLimits?.hasData == true } ? .proPlan : .enterprise
            return PopoverAccountGroup(
                accountID: accountID, accountName: sample.accountName, accountType: inferredType,
                active: active, idle: idle
            )
        }
    }
}
