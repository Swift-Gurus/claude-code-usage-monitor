import Foundation

/**
 solid-name: StatsSessionFileResolving
 solid-category: abstraction
 solid-description: Contract for resolving every session transcript file active within a reporting period, across all accounts.
 */
protocol StatsSessionFileResolving: Sendable {
    func resolveFiles(accounts: [Account], monthStart: Date) async -> Set<URL>
}

/**
 solid-name: StatsSessionFileResolver
 solid-category: service
 solid-description: Resolves all session transcript files for specified accounts within a reporting period.
 */
actor StatsSessionFileResolver: StatsSessionFileResolving {
    private let workingDirCollector: SessionWorkingDirCollecting
    private let sessionResolver: StatsSessionResolving

    init(
        workingDirCollector: SessionWorkingDirCollecting = SessionWorkingDirCollector(),
        sessionResolver: StatsSessionResolving = StatsSessionResolver()
    ) {
        self.workingDirCollector = workingDirCollector
        self.sessionResolver = sessionResolver
    }

    func resolveFiles(accounts: [Account], monthStart: Date) async -> Set<URL> {
        var files: Set<URL> = []
        for account in accounts {
            for (sessionID, workingDir) in workingDirs(for: account, since: monthStart) {
                files.formUnion(sessionResolver.resolveSessionFiles(sessionID: sessionID, workingDir: workingDir, projectsDir: account.projectsDir))
            }
        }
        return files
    }

    private func workingDirs(for account: Account, since monthStart: Date) -> [String: String] {
        var result = workingDirCollector.collect(under: account.usageDir, since: monthStart)
        result.merge(workingDirCollector.collect(under: account.commanderDir, since: monthStart)) { $1 }
        return result
    }
}
