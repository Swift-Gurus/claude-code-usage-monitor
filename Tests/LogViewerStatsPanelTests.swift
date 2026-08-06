import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: LogViewerStatsPanelTests
 solid-category: unit-test
 solid-description: Verifies session statistics control inline log-viewer panel visibility.
 */
@Suite("Log Viewer Stats Panel")
struct LogViewerStatsPanelTests {
    @Test("Token-only sessions expose the inline stats panel")
    @MainActor
    func tokenOnlySessionsExposeInlineStatsPanel() {
        let panel = LogViewerSidePanel(
            showTaskPanel: false,
            taskList: [],
            completedTaskCount: 0,
            showStatsPanel: true,
            sessionStats: SessionStats(tokens: SessionTokenStats(inputTokens: 1))
        )

        #expect(panel.hasStats)
        #expect(panel.isVisible)
    }
}
