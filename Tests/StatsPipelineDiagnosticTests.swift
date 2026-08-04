import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: StatsPipelineDiagnosticTests
 solid-category: unit-test
 solid-description: Diagnostic tests verifying that stats pipeline collects real session data, resolves files correctly, and produces valid monthly aggregations.
 */
@Suite("StatsPipelineDiagnostic")
struct StatsPipelineDiagnosticTests {
    private var account: Account { Account(name: "Default", claudeDir: NSHomeDirectory() + "/.claude") }
    private var boundaries: PeriodBoundaries { PeriodBoundaries(now: Date()) }
    private var resolvedFiles: Set<URL> {
        get async {
            await StatsSessionFileResolver().resolveFiles(accounts: [account], monthStart: boundaries.monthStart)
        }
    }

    @Test("working dirs are collected from real usage data")
    func collectsWorkingDirs() {
        let workingDirs = SessionWorkingDirCollector().collect(under: account.usageDir, since: boundaries.monthStart)
        print("workingDirs:", workingDirs)
        #expect(!workingDirs.isEmpty)
    }

    @Test("session files resolve to existing paths")
    func resolvesFiles() async {
        let resolvedFiles = await resolvedFiles
        print("resolved:", resolvedFiles.map(\.path))
        let existing = resolvedFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
        print("existing:", existing.map(\.path))
        #expect(!existing.isEmpty)
    }

    @Test("aggregation and rollup produce non-zero month totals")
    func rollsUpNonZero() async {
        let resolvedFiles = await resolvedFiles
        let statsByDay = await StatsFileAggregator().aggregate(files: resolvedFiles)
        print("statsByDay:", statsByDay.mapValues { $0.tools.total })
        let rollup = DefaultStatsRollupProvider().rollup(statsByDay: statsByDay, boundaries: boundaries)
        print("month tools:", rollup.month.tools.total)
        #expect(rollup.month.tools.total > 0)
    }
}
