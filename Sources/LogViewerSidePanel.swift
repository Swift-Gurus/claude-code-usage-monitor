import SwiftUI

/// Combines the task-list panel and the stats panel into one side-panel slot, since the
/// surrounding layout containers (StickyHeaderContainer, LogContentSection) only expose
/// a single `taskPanel` slot.
struct LogViewerSidePanel: View {
    let showTaskPanel: Bool
    let taskList: [TaskListItem]
    let completedTaskCount: Int
    let showStatsPanel: Bool
    let sessionStats: SessionStats

    var isVisible: Bool {
        (showTaskPanel && !taskList.isEmpty) || (showStatsPanel && hasStats)
    }

    var hasStats: Bool {
        sessionStats.tools.total > 0 || sessionStats.mcp.total > 0 || sessionStats.tokens.total > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            taskPanelIfShown
            dividerIfBothShown
            statsPanelIfShown
        }
    }

    private var showTaskArea: Bool { showTaskPanel && !taskList.isEmpty }
    private var showStatsArea: Bool { showStatsPanel && hasStats }

    @ViewBuilder
    private var taskPanelIfShown: some View {
        if showTaskArea {
            LogViewerTaskPanelSubview(tasks: taskList, completedCount: completedTaskCount)
        }
    }

    @ViewBuilder
    private var dividerIfBothShown: some View {
        if showTaskArea && showStatsArea {
            Divider()
        }
    }

    @ViewBuilder
    private var statsPanelIfShown: some View {
        if showStatsArea {
            StatsPanelView(stats: sessionStats)
        }
    }
}

#Preview {
    LogViewerSidePanel(
        showTaskPanel: true,
        taskList: [TaskListItem(id: "1", content: "Sample task", status: "pending", activeForm: "Doing sample task")],
        completedTaskCount: 0,
        showStatsPanel: true,
        sessionStats: SessionStats(tools: ToolCallStats(countsByName: ["Bash": 2]))
    )
}
