import SwiftUI

/**
 solid-name: TaskPanelView
 solid-category: view-component
 solid-description: Displays task completion progress and task details in a panel.
 */
struct TaskPanelView: View {
    let tasks: [TaskListItem]
    let completedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TaskPanelHeaderView(completedCount: completedCount, totalCount: tasks.count)
            progressBarIfNeeded
            TaskChecklistView(tasks: tasks)
        }
        .padding(10)
    }

    @ViewBuilder
    private var progressBarIfNeeded: some View {
        if !tasks.isEmpty {
            ContextProgressBar(
                contextPercent: TaskCompletionPercent(completed: completedCount, total: tasks.count).value,
                label: "", barHeight: 4
            )
        }
    }
}

#Preview {
    TaskPanelView(
        tasks: [
            TaskListItem(id: "1", content: "Investigate crash", status: "completed", activeForm: "Investigating crash"),
            TaskListItem(id: "2", content: "Write fix", status: "in_progress", activeForm: "Writing fix"),
            TaskListItem(id: "3", content: "Add tests", status: "pending", activeForm: "Adding tests"),
        ],
        completedCount: 1
    )
    .frame(width: 200, height: 200)
}