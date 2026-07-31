import SwiftUI

/// Thin wrapper isolating TaskPanelView from LogViewerView's body.
struct LogViewerTaskPanelSubview: View {
    let tasks: [TaskListItem]
    let completedCount: Int

    var body: some View {
        TaskPanelView(tasks: tasks, completedCount: completedCount)
    }
}

#Preview {
    LogViewerTaskPanelSubview(
        tasks: [TaskListItem(id: "1", content: "Sample task", status: "pending", activeForm: "Doing sample task")],
        completedCount: 0
    )
}
