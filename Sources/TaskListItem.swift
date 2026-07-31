/// A task item reconstructed from TaskCreate/TaskUpdate/TodoWrite tool calls in JSONL logs.
/// Used in both log viewer and subagent detail views to display task progress.
struct TaskListItem: Identifiable, StatusRowDisplayable {
    let id: String
    var content: String
    var status: String
    var activeForm: String
}
