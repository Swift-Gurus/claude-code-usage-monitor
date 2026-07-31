import SwiftUI

/**
 solid-name: TaskRowsList
 solid-category: view-component
 solid-description: Displays a collection of tasks in vertical order.
 */
struct TaskRowsList: View {
    let tasks: [TaskListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            TaskRowsContent(tasks: tasks)
        }
    }
}

#Preview {
    TaskRowsList(tasks: [
        TaskListItem(id: "1", content: "Completed task", status: "completed", activeForm: ""),
        TaskListItem(id: "2", content: "Pending task", status: "pending", activeForm: ""),
    ])
}
