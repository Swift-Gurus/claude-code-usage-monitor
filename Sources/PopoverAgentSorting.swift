/// Sorts agents by the user's preferred order for the popover's agent list.
struct PopoverAgentSorting {
    let sortOrder: AgentSortOrder

    func sorted(_ agents: [AgentInfo]) -> [AgentInfo] {
        switch sortOrder {
        case .recentlyUpdated: return agents.sorted { $0.updatedAt > $1.updatedAt }
        case .cost: return agents.sorted { $0.cost > $1.cost }
        case .contextUsage: return agents.sorted { $0.contextPercent > $1.contextPercent }
        }
    }
}
