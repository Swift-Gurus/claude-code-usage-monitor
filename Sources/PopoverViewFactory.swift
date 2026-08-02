import SwiftUI

/// Builds the popover's root view, wiring the concrete agent-list view model.
public enum PopoverViewFactory {
    public static func make(data: UsageData, agentTracker: AgentTracker, settings: AppSettings, sessionManager: SessionManager) -> some View {
        PopoverView(
            data: data, agentTracker: agentTracker, settings: settings, sessionManager: sessionManager,
            mainViewModel: PopoverMainViewModel(settings: settings, agentTracker: agentTracker, data: data)
        )
    }
}
