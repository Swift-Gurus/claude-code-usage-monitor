/**
 solid-name: LogViewerActions
 solid-category: abstraction
 solid-description: Contract that coordinates all operations of a log viewer.
 */
protocol LogViewerActions {
    func loadMessages() async
    func startViewLifecycle(bridge: TTYBridge?) async
    func send(_ text: String, via bridge: TTYBridge?)
}