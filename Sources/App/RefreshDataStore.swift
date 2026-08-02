import ClaudeUsageBarLib
import Foundation

/// Owns the usage/agent data stores and the accounts they track.
@MainActor
final class RefreshDataStore {
    let usageData: UsageData
    let agentTracker: AgentTracker
    private let fileRefresher: FileRefreshing

    init(usageData: UsageData, agentTracker: AgentTracker, fileRefresher: FileRefreshing = DefaultFileRefresher()) {
        self.usageData = usageData
        self.agentTracker = agentTracker
        self.fileRefresher = fileRefresher
    }

    func updateAccounts(_ accounts: [Account]) {
        usageData.accounts = accounts
        agentTracker.accounts = accounts
    }

    func reloadFromDisk(accounts: [Account], completion: @escaping () -> Void) {
        fileRefresher.refreshFiles(accounts: accounts)
        usageData.reload()
        agentTracker.reload(completion: completion)
    }
}
