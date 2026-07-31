import SwiftUI

/**
 solid-name: TaskRowsContent
 solid-category: view-component
 solid-description: Displays tasks as individual rows in a list.
 */
struct TaskRowsContent: View {
    let tasks: [TaskListItem]

    var body: some View {
        ForEach(tasks) { item in
            StatusRowView(item: item)
        }
    }
}

#Preview {
    TaskRowsContent(tasks: [
        TaskListItem(id: "1", content: "Sample", status: "pending", activeForm: "")
    ])
}
