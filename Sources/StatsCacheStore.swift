import Foundation

/**
 solid-name: StatsCacheStore
 solid-category: crud
 solid-stack: [structured-concurrency]
 solid-description: Tracks account usage-statistics snapshots and publishes refreshed values for presentation.
 */
/// Tracks each account's cached usage-stats snapshot, loaded off the main actor.
@Observable
@MainActor
final class StatsCacheStore {
    private(set) var caches: [UUID: StatsCache] = [:]

    private let reader: any StatsCacheReading
    private let runner: any ReloadTaskRunning

    init(reader: any StatsCacheReading, runner: any ReloadTaskRunning) {
        self.reader = reader
        self.runner = runner
    }

    convenience init() {
        self.init(reader: StatsCacheReader(), runner: ReloadTaskRunner())
    }

    func reload(accounts: [Account]) {
        let reader = reader
        runner.run { [weak self] in
            let loadedCaches = accounts.reduce(into: [UUID: StatsCache]()) { caches, account in
                if let stats = reader.read(claudeDirectory: account.claudeDir) {
                    caches[account.id] = stats
                }
            }
            await self?.updateCaches(loadedCaches)
        }
    }

    @MainActor
    private func updateCaches(_ caches: [UUID: StatsCache]) {
        self.caches = caches
    }
}
