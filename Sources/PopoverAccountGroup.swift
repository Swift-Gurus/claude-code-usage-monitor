import Foundation

/// Agents (active + idle) belonging to one account, for grouped display in the popover.
public struct PopoverAccountGroup: Identifiable {
    let accountID: UUID
    let accountName: String
    let accountType: AccountType
    let active: [AgentInfo]
    let idle: [AgentInfo]

    public var id: UUID { accountID }
    var totalCount: Int { active.count + idle.count }
}
