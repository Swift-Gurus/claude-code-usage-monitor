/**
 solid-name: TaskStateProviding
 solid-category: abstraction
 solid-description: Contract that provides task-management state for log-viewer sessions.
 */
protocol TaskStateProviding {
    var taskList: [TaskListItem] { get }
    var completedTaskCount: Int { get }
    var toolResultLookup: [String: String] { get }
}