import Foundation

/// Runs one detached background task at a time, cancelling any prior run before starting a new one.
final class ReloadTaskRunner {
    private var task: Task<Void, Never>?

    deinit { task?.cancel() }

    func run(_ work: @escaping () async -> Void) {
        task?.cancel()
        task = Task.detached(priority: .utility) { await work() }
    }
}
