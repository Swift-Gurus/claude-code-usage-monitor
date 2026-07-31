import SwiftUI

/**
 solid-name: TodoChecklistView
 solid-category: view-component
 solid-description: Displays a list of todo items with their completion status.
 */
struct TodoChecklistView: View {
    let todos: [TodoItem]

    var body: some View {
        rows
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 4) {
            EnumeratedListContent(items: TodoListRows(todos: todos).items) { item in
                StatusRowView(item: item)
            }
        }
    }
}

#Preview {
    TodoChecklistView(todos: [
        TodoItem(content: "Write tests", status: "completed"),
        TodoItem(content: "Fix bug", status: "in_progress"),
    ])
}
