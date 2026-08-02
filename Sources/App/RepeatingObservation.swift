import Observation
import os

/// Re-registers `withObservationTracking` on a value each time it changes, notifying the
/// caller with the new value. Cancels its pending re-registration task on deallocation.
///
/// `withObservationTracking`'s `onChange` fires on an unspecified thread, so the pending
/// task handle is guarded by a lock rather than actor isolation.
@MainActor
final class RepeatingObservation<Value> {
    private let read: () -> Value
    private let onChange: (Value) -> Void
    private let taskBox = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    init(read: @escaping () -> Value, onChange: @escaping (Value) -> Void) {
        self.read = read
        self.onChange = onChange
    }

    deinit {
        taskBox.withLock { $0?.cancel() }
    }

    func start() {
        withObservationTracking {
            _ = read()
        } onChange: { [weak self] in
            guard let self else { return }
            let newTask = Task { @MainActor [weak self] in
                guard let self else { return }
                onChange(read())
                start()
            }
            taskBox.withLock { $0 = newTask }
        }
    }
}
