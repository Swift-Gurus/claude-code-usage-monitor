import Foundation
import Testing
@testable import ClaudeUsageBarLib

@Suite("AgentInfo")
struct AgentInfoTests {

    private func makeAgent(
        pid: Int = 1, model: String = "Opus 4.6", agentName: String = "",
        contextPercent: Int = 50, contextWindow: Int = 1_000_000,
        cost: Double = 10.0, linesAdded: Int = 100, linesRemoved: Int = 50,
        workingDir: String = "/Users/test/project", sessionID: String = "abc",
        durationMs: Double = 120_000, apiDurationMs: Double = 60_000,
        updatedAt: TimeInterval = Date().timeIntervalSince1970,
        cpuUsage: Double = 5.0, isIdle: Bool = false, source: AgentSource = .cli
    ) -> AgentInfo {
        AgentInfo(
            pid: pid, model: model, agentName: agentName,
            contextPercent: contextPercent, contextWindow: contextWindow,
            cost: cost, linesAdded: linesAdded, linesRemoved: linesRemoved,
            workingDir: workingDir, sessionID: sessionID,
            durationMs: durationMs, apiDurationMs: apiDurationMs,
            updatedAt: updatedAt, cpuUsage: cpuUsage, isIdle: isIdle, source: source
        )
    }

    // MARK: - displayName

    @Test("displayName returns agentName when set")
    func displayNameWithAgent() {
        let agent = makeAgent(agentName: "my-agent")
        #expect(agent.displayName == "my-agent")
    }

    @Test("displayName falls back to model when agentName is empty")
    func displayNameFallback() {
        let agent = makeAgent(model: "Sonnet 4.6", agentName: "")
        #expect(agent.displayName == "Sonnet 4.6")
    }

    // MARK: - shortDir

    @Test("shortDir returns last path component")
    func shortDir() {
        let agent = makeAgent(workingDir: "/Users/test/my-project")
        #expect(agent.shortDir == "my-project")
    }

    @Test("shortDir handles root path")
    func shortDirRoot() {
        let agent = makeAgent(workingDir: "/")
        #expect(agent.shortDir == "/")
    }

    // MARK: - contextWindowText

    @Test("contextWindowText for 1M")
    func contextWindow1M() {
        let agent = makeAgent(contextWindow: 1_000_000)
        #expect(agent.contextWindowText == "1M")
    }

    @Test("contextWindowText for 200K shows 0.2M")
    func contextWindow200K() {
        let agent = makeAgent(contextWindow: 200_000)
        #expect(agent.contextWindowText == "0.2M")
    }

    @Test("contextWindowText for 0 returns empty")
    func contextWindowZero() {
        let agent = makeAgent(contextWindow: 0)
        #expect(agent.contextWindowText == "")
    }

    // MARK: - durationText

    @Test("durationText formats minutes and seconds")
    func durationMinutes() {
        let agent = makeAgent(durationMs: 125_000) // 2m 5s
        #expect(agent.durationText == "2m 5s")
    }

    @Test("durationText formats hours")
    func durationHours() {
        let agent = makeAgent(durationMs: 3_700_000) // 61m 40s → 1h 1m
        #expect(agent.durationText == "1h 1m")
    }

    @Test("durationText for zero")
    func durationZero() {
        let agent = makeAgent(durationMs: 0)
        #expect(agent.durationText == "0m 0s")
    }

    // MARK: - idleText

    @Test("idleText empty when recently updated")
    func idleTextRecent() {
        let agent = makeAgent(updatedAt: Date().timeIntervalSince1970)
        #expect(agent.idleText == "")
    }

    @Test("idleText shows minutes when idle")
    func idleTextMinutes() {
        let agent = makeAgent(updatedAt: Date().timeIntervalSince1970 - 3600) // exactly 60 min ago
        #expect(agent.idleText == "1h 0m idle")
    }

    @Test("idleText shows hours when long idle")
    func idleTextHours() {
        // Use a fixed past date far enough back that timing can't affect it
        let agent = makeAgent(updatedAt: Date().timeIntervalSince1970 - 10_800) // exactly 3h ago
        #expect(agent.idleText == "3h 0m idle")
    }

    // MARK: - id

    @Test("id returns pid")
    func idIsPid() {
        let agent = makeAgent(pid: 42)
        #expect(agent.id == 42)
    }
}
