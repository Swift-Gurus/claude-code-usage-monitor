import Foundation

/// Runs one refresh at a time, dropping requests that arrive while a refresh is in flight.
final class RefreshDebouncer {
    private var inFlight = false

    func run(_ work: (@escaping () -> Void) -> Void, completion: @escaping () -> Void) {
        guard !inFlight else { return }
        inFlight = true
        work { [weak self] in
            self?.inFlight = false
            completion()
        }
    }
}
