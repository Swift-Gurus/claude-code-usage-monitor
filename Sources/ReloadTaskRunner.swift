import Foundation

/**
 solid-name: ReloadTaskRunning
 solid-category: abstraction
 solid-stack: [structured-concurrency]
 solid-description: Contract for replacing an active background reload operation with new asynchronous work.
 */
@MainActor
protocol ReloadTaskRunning: Sendable {
    func run(_ work: @escaping @Sendable () async -> Void)
}

/**
 solid-name: ReloadTaskRunner
 solid-category: utility
 solid-stack: [structured-concurrency]
 solid-description: Manages a single background task, automatically cancelling any prior execution before starting a new one.
 */
@MainActor
final class ReloadTaskRunner: ReloadTaskRunning {
    private var task: Task<Void, Never>?

    deinit { task?.cancel() }

    func run(_ work: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task.detached(priority: .utility) { await work() }
    }
}
