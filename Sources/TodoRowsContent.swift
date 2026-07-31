import SwiftUI

/**
 solid-name: TodoRowsContent
 solid-category: view-component
 solid-description: Displays a collection of todo items as individual row views.
 */
struct TodoRowsContent: View {
    let todos: [TodoItem]

    var body: some View {
        ForEach(Array(todos.enumerated()), id: \.offset) { _, item in
            TodoRowView(item: item)
        }
    }
}

#Preview {
    TodoRowsContent(todos: [TodoItem(content: "Sample", status: "pending")])
}
