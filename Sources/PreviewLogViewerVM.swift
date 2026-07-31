import Foundation

/// Preview-only mock ViewModel for LogViewerView. Lives at file scope (not nested inside
/// a #Preview block) because @Observable cannot attach to a type declared locally inside
/// a function or closure — a compiler restriction, not a style choice.
@Observable
final class PreviewLogViewerVM: LogViewerState, LogViewerActions {
    var messages: [LogMessage] = []
    var displayedMessages: [LogMessage] = []
    var isLoading = false
    var taskList: [TaskListItem] = [
        TaskListItem(id: "1", content: "Investigate crash", status: "completed", activeForm: "Investigating crash"),
        TaskListItem(id: "2", content: "Write fix", status: "in_progress", activeForm: "Writing fix"),
    ]
    var completedTaskCount: Int { taskList.filter { $0.status == "completed" }.count }
    var toolResultLookup: [String: String] = [:]
    var pendingPrompt: LogToolCall?
    var sessionStats: SessionStats = SessionStats()
    var fileURL: URL { URL(fileURLWithPath: "/tmp/preview.jsonl") }
    func roleLabel(_ msg: LogMessage) -> String { "Assistant" }
    func loadMessages() async {}
    func startViewLifecycle(bridge: TTYBridge?) async {}
    func send(_ text: String, via bridge: TTYBridge?) {}
}
