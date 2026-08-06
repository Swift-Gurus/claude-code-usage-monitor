import Foundation

struct StatsSessionFile: Hashable, Sendable {
    enum Format: Hashable, Sendable {
        case claude
        case codex
    }

    let url: URL
    let format: Format
}

/**
 solid-name: StatsSessionFileResolving
 solid-category: abstraction
 solid-description: Contract for resolving every session transcript file active within a reporting period, across all accounts.
 */
protocol StatsSessionFileResolving: Sendable {
    func resolveFiles(accounts: [Account], monthStart: Date) async -> Set<StatsSessionFile>
}

/**
 solid-name: StatsSessionFileResolver
 solid-category: service
 solid-description: Resolves all session transcript files for specified accounts within a reporting period.
 */
actor StatsSessionFileResolver: StatsSessionFileResolving {
    private let workingDirCollector: SessionWorkingDirCollecting
    private let sessionResolver: StatsSessionResolving
    private let codexRolloutStore: CodexRolloutReading

    init(
        workingDirCollector: SessionWorkingDirCollecting = SessionWorkingDirCollector(),
        sessionResolver: StatsSessionResolving = StatsSessionResolver(),
        codexRolloutStore: CodexRolloutReading? = nil
    ) {
        self.workingDirCollector = workingDirCollector
        self.sessionResolver = sessionResolver
        self.codexRolloutStore = codexRolloutStore ?? CodexRolloutStore(paths: CodexPaths())
    }

    func resolveFiles(accounts: [Account], monthStart: Date) async -> Set<StatsSessionFile> {
        var files = Set(codexRolloutStore.rolloutURLs(modifiedSince: monthStart).map {
            StatsSessionFile(url: $0, format: .codex)
        })
        for account in accounts {
            for (sessionID, workingDir) in workingDirs(for: account, since: monthStart) {
                files.formUnion(
                    sessionResolver
                        .resolveSessionFiles(sessionID: sessionID, workingDir: workingDir, projectsDir: account.projectsDir)
                        .map { StatsSessionFile(url: $0, format: .claude) }
                )
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
