import Foundation

/**
 solid-name: PopoverAgentListViewActions
 solid-category: abstraction
 solid-description: Contract that defines operations required by agent list popover views.
 */
public protocol PopoverAgentListViewActions {
    func updateRowHeights(_ heights: [Int: CGFloat])
    func headerData(for group: PopoverAccountGroup, rateLimitEvents: [UUID: RateLimitEvent], statsCaches: [UUID: StatsCache]) -> PopoverAccountHeaderData
    func liveAgent(for agent: AgentInfo) -> AgentInfo
}
