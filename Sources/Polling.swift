/**
 solid-name: poll
 solid-category: utility
 solid-description: Standalone async polling helper that repeatedly executes a work closure at a fixed interval until the enclosing Task is cancelled. Eliminates duplicated polling loops across ViewModels.
 */
func poll(interval: Duration, work: @Sendable () async -> Void) async {
    while !Task.isCancelled {
        try? await Task.sleep(for: interval)
        await work()
    }
}
