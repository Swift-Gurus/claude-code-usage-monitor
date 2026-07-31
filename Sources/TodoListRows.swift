/**
 solid-name: TodoListRows
 solid-category: model
 solid-description: Transforms items into display-ready rows with generated identifiers.
 */
struct TodoListRows {
    let items: [TaskListItem]

    init(todos: [TodoItem]) {
        items = todos.enumerated().map { idx, item in
            TaskListItem(id: "todo-\(idx)", content: item.content, status: item.status, activeForm: "")
        }
    }
}
