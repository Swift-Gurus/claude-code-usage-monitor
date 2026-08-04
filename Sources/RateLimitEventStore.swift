import Foundation

/// Tracks each account's most recent rate-limit event, loaded off the main actor.
@Observable
@MainActor
final class RateLimitEventStore {
    private(set) var events: [UUID: RateLimitEvent] = [:]

    private let loader: RateLimitEventLoading
    private let runner = ReloadTaskRunner()

    init(loader: RateLimitEventLoading = DefaultRateLimitEventLoader()) {
        self.loader = loader
    }

    func reload(accounts: [Account]) {
        let loader = loader
        runner.run { [weak self] in
            var events: [UUID: RateLimitEvent] = [:]
            for account in accounts {
                if let event = loader.lastEvent(claudeDir: account.claudeDir) {
                    events[account.id] = event
                }
            }
            await self?.updateEvents(events)
        }
    }

    @MainActor
    private func updateEvents(_ events: [UUID: RateLimitEvent]) {
        self.events = events
    }
}
