import Foundation

/**
 solid-name: TaskListReconstruction
 solid-category: model
 solid-description: Reconstructs task and interaction state from message history.
 */
struct TaskListReconstruction {
    let tasks: [TaskListItem]
    let toolResultLookup: [String: String]
    let pendingPrompt: LogToolCall?

    init(messages: [LogMessage]) {
        var tasks: [TaskListItem] = []
        var nextId = 1
        var lookup: [String: String] = [:]
        var resolvedIDs: Set<String> = []

        for msg in messages {
            resolvedIDs.formUnion(msg.toolResultIDs)
            for (tid, content) in msg.toolResultContents {
                lookup[tid] = content
            }
            for tc in msg.toolCalls {
                switch tc.data {
                case .todoWrite(let d):
                    tasks = d.todos.enumerated().map { idx, item in
                        TaskListItem(id: "todo-\(idx)", content: item.content, status: item.status, activeForm: "")
                    }
                case .taskCreate(let d):
                    let id = "\(nextId)"
                    nextId += 1
                    tasks.append(TaskListItem(id: id, content: d.subject, status: "pending", activeForm: d.activeForm))
                case .taskUpdate(let d):
                    if let idx = tasks.firstIndex(where: { $0.id == d.taskId }), !d.status.isEmpty {
                        tasks[idx].status = d.status
                    }
                default:
                    break
                }
            }
        }

        var prompt: LogToolCall?
        for msg in messages.reversed() where msg.role == .assistant {
            if let unresolved = msg.toolCalls.reversed().first(where: { !resolvedIDs.contains($0.id) && $0.data.needsPrompt }) {
                prompt = unresolved
                break
            }
        }

        self.tasks = tasks
        self.toolResultLookup = lookup
        self.pendingPrompt = prompt
    }
}
