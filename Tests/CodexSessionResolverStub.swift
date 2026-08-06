import Foundation
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexSessionResolverStub
 solid-category: test-double
 solid-description: Supplies a fixed Claude session file to resolver tests.
 */
struct CodexSessionResolverStub: StatsSessionResolving {
    let url: URL

    func resolveSessionFiles(sessionID: String, workingDir: String, projectsDir: URL) -> [URL] {
        [url]
    }
}
