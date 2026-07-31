import Foundation

/**
 solid-name: LogViewerViewModel
 solid-category: viewmodel
 solid-stack: [structured-concurrency]
 solid-description: Manages log messages, task state, and view lifecycle for the log viewer.
 */
@Observable
final class LogViewerViewModel: LogViewerState, LogViewerActions {
    private(set) var messages: [LogMessage] = []
    private(set) var displayedMessages: [LogMessage] = []
    private(set) var isLoading = true
    private(set) var taskList: [TaskListItem] = []
    private(set) var completedTaskCount = 0
    private(set) var toolResultLookup: [String: String] = [:]
    private(set) var pendingPrompt: LogToolCall?
    private(set) var sessionStats = SessionStats()
    private var lastMtime: Date?
    private var activityTask: Task<Void, Never>?

    private let agent: AgentInfo
    private let target: LogTarget
    private let parser: LogMessageParsing
    private let modelResolver: ModelResolving
    private let urlResolver: LogURLResolving
    private let fileSystem: FileSystemProviding

    init(
        agent: AgentInfo,
        target: LogTarget,
        parser: LogMessageParsing = LogParser(),
        modelResolver: ModelResolving = ClaudeModelAdapter(),
        urlResolver: LogURLResolving = LogURLResolver(),
        fileSystem: FileSystemProviding = FileManager.default
    ) {
        self.agent = agent
        self.target = target
        self.parser = parser
        self.modelResolver = modelResolver
        self.urlResolver = urlResolver
        self.fileSystem = fileSystem
    }

    deinit {
        activityTask?.cancel()
    }

    var fileURL: URL {
        urlResolver.resolveURL(agent: agent, target: target)
    }

    func roleLabel(_ msg: LogMessage) -> String {
        switch msg.role {
        case .user: return "User"
        case .assistant:
            if let model = msg.model, !model.isEmpty {
                return modelResolver.resolve(modelID: model).displayName
            }
            return "Assistant"
        case .system: return "Hook"
        }
    }

    func loadMessages() async {
        let url = fileURL
        let cached = lastMtime
        let fs = fileSystem

        let (msgs, mtime): ([LogMessage], Date?) = await Task.detached(priority: .utility) { [parser] in
            let attrs = try? fs.attributesOfItem(atPath: url.path)
            let mtime = attrs?[.modificationDate] as? Date
            if let cached, let mtime, cached == mtime {
                return ([], mtime)
            }
            return (parser.parseMessages(at: url), mtime)
        }.value

        if let mtime { lastMtime = mtime }
        if !msgs.isEmpty {
            messages = msgs
            rebuildDerivedState(from: msgs)
        }
        isLoading = false
    }

    func startViewLifecycle(bridge: TTYBridge?) async {
        if let bridge {
            bridge.onActivity = { [weak self] in
                self?.activityTask?.cancel()
                self?.activityTask = Task { await self?.loadMessages() }
            }
        }
        await loadMessages()
        await poll(interval: .seconds(2)) { [weak self] in
            await self?.loadMessages()
        }
    }

    func send(_ text: String, via bridge: TTYBridge?) {
        bridge?.send(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func rebuildDerivedState(from messages: [LogMessage]) {
        displayedMessages = messages.filter { !$0.textContent.isEmpty || !$0.toolCalls.isEmpty || $0.thinking != nil }

        let reconstruction = TaskListReconstruction(messages: messages)
        taskList = reconstruction.tasks
        completedTaskCount = reconstruction.tasks.filter { $0.status == "completed" }.count
        toolResultLookup = reconstruction.toolResultLookup
        pendingPrompt = reconstruction.pendingPrompt
        sessionStats = SessionStatsAggregator(messages: messages).aggregate()
    }
}
