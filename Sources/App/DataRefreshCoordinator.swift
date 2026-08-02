import ClaudeUsageBarLib
import Foundation

/// Runs the periodic + on-demand refresh cycle for a `RefreshDataStore`.
@MainActor
final class DataRefreshCoordinator {
    private let dataStore: RefreshDataStore
    private let debouncer: RefreshDebouncer
    private let monitorFactory: (@escaping () -> Void) -> UsageMonitor
    private var monitor: UsageMonitor?

    init(
        dataStore: RefreshDataStore,
        debouncer: RefreshDebouncer = RefreshDebouncer(),
        monitorFactory: @escaping (@escaping () -> Void) -> UsageMonitor
    ) {
        self.dataStore = dataStore
        self.debouncer = debouncer
        self.monitorFactory = monitorFactory
    }

    func startMonitoring(onTick: @escaping () -> Void) {
        monitor = monitorFactory { [weak self] in
            self?.scheduleRefresh(completion: onTick)
        }
    }

    /// Debounced refresh — drops the request if one is already in flight.
    func scheduleRefresh(completion: @escaping () -> Void) {
        debouncer.run({ done in self.refreshNow(completion: done) }, completion: completion)
    }

    /// Immediate refresh, used when the UI is opened and must show current data right away.
    func refreshNow(completion: @escaping () -> Void) {
        dataStore.reloadFromDisk(accounts: dataStore.usageData.accounts, completion: completion)
    }

    func updateAccounts(_ accounts: [Account]) {
        dataStore.updateAccounts(accounts)
        monitor?.updateAccounts(accounts)
    }
}
