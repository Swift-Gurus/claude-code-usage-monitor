import Foundation
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexWorkingDirCollectorStub
 solid-category: test-double
 solid-description: Supplies a fixed Codex session working directory to resolver tests.
 */
struct CodexWorkingDirCollectorStub: SessionWorkingDirCollecting {
    func collect(under root: URL, since monthStart: Date) -> [String: String] {
        ["session-1": "/tmp/project"]
    }
}
