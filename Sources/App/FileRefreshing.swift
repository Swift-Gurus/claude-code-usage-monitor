import ClaudeUsageBarLib

/// Refreshes the on-disk Commander files backing usage stats.
protocol FileRefreshing {
    func refreshFiles(accounts: [Account])
}

struct DefaultFileRefresher: FileRefreshing {
    func refreshFiles(accounts: [Account]) {
        CommanderSupport.refreshFiles(accounts: accounts)
    }
}
