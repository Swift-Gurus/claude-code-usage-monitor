import Foundation

/// One row in the popover's flattened agent list: a divider, an account header, or an agent.
public enum PopoverAgentListItem: Identifiable {
    case divider(String)
    case header(PopoverAccountGroup)
    case agent(AgentInfo)

    public var id: String {
        switch self {
        case .divider(let key): return "div-\(key)"
        case .header(let group): return "header-\(group.accountID.uuidString)"
        case .agent(let agent): return "agent-\(agent.pid)"
        }
    }
}

/// Flattens grouped accounts into dividers + headers + agents, for indexed row-height measurement.
struct PopoverAgentListFlattener {
    let groups: [PopoverAccountGroup]

    var items: [PopoverAgentListItem] {
        var items: [PopoverAgentListItem] = []
        for (index, group) in groups.enumerated() {
            if index > 0 { items.append(.divider(group.accountID.uuidString)) }
            items.append(.header(group))
            for agent in group.active { items.append(.agent(agent)) }
            for agent in group.idle { items.append(.agent(agent)) }
        }
        return items
    }
}
