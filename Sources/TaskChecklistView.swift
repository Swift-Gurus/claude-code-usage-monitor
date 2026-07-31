import SwiftUI

/**
 solid-name: TaskChecklistView
 solid-category: view-component
 solid-description: Displays a scrollable list of task items.
 */
struct TaskChecklistView: View {
    let tasks: [TaskListItem]

    var body: some View {
        ScrollView {
            TaskRowsList(tasks: tasks)
        }
    }
}

#Preview {
    TaskChecklistView(tasks: [
        TaskListItem(id: "1", content: "Completed task", status: "completed", activeForm: ""),
        TaskListItem(id: "2", content: "Pending task", status: "pending", activeForm: ""),
    ])
}
