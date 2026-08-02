import Foundation

/// Owns which screen the popover is currently showing and the transitions between them.
@Observable
final class PopoverNavigationState {
    private(set) var showSettings = false
    private(set) var selectedAgent: AgentInfo?
    private(set) var selectedPeriod: String?
    private(set) var statsPagePeriod: StatusBarPeriod?
    var filterAccountID: UUID?

    func openSettings() { showSettings = true }
    func closeSettings() { showSettings = false }

    func select(agent: AgentInfo) { selectedAgent = agent }
    func dismissAgent() { selectedAgent = nil }

    func select(period: String) { selectedPeriod = period }
    func dismissPeriod() { selectedPeriod = nil }

    func viewStatsPage(for label: String) {
        statsPagePeriod = periodEnum(for: label)
        selectedPeriod = nil
    }
    func dismissStatsPage() { statsPagePeriod = nil }

    private func periodEnum(for label: String) -> StatusBarPeriod {
        switch label {
        case "Week": return .week
        case "Month": return .month
        default: return .day
        }
    }
}
