import SwiftUI

/**
 solid-name: PopoverAgentListViewState
 solid-category: abstraction
 solid-description: Contract that defines observable state for a viewport-aware agent list.
 */
public protocol PopoverAgentListViewState: Observable {
    var items: [PopoverAgentListItem] { get }
    var hasAgents: Bool { get }
    var agentViewportHeight: CGFloat? { get }
}
