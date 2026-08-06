import Foundation
@testable import ClaudeUsageBarLib

/**
 solid-name: CodexStatsScenarioRunning
 solid-category: abstraction
 solid-description: Contract for producing aggregate statistics from a Codex JSONL test scenario.
 */
protocol CodexStatsScenarioRunning {
    func aggregate(_ content: String) throws -> SessionStats
}
