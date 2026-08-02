import Foundation

/// Tracks each account's cached usage-stats snapshot, loaded off the main actor.
@Observable
final class StatsCacheStore {
    private(set) var caches: [UUID: StatsCache] = [:]

    private let loader: (String) -> StatsCache?
    private let runner = ReloadTaskRunner()

    init(loader: @escaping (String) -> StatsCache? = StatsCache.load) {
        self.loader = loader
    }

    func reload(accounts: [Account]) {
        let loader = loader
        runner.run { [weak self] in
            let loadedCaches = accounts.reduce(into: [UUID: StatsCache]()) { caches, account in
                if let stats = loader(account.claudeDir) {
                    caches[account.id] = stats
                }
            }
            await MainActor.run { [weak self] in self?.caches = loadedCaches }
        }
    }
}
