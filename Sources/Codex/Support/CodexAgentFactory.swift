import Foundation

struct CodexAgentFactory {
    let accountID: UUID
    let accountName: String
    let claudeDir: String
    let pidOffset: Int

    init(
        accountID: UUID,
        accountName: String,
        claudeDir: String,
        pidOffset: Int = 2_000_000
    ) {
        self.accountID = accountID
        self.accountName = accountName
        self.claudeDir = claudeDir
        self.pidOffset = pidOffset
    }

    func makeAgent(from session: CodexSession) -> AgentInfo {
        AgentInfo(
            pid: syntheticPID(for: session.threadID),
            model: session.model.isEmpty ? "Codex" : session.model,
            agentName: session.title,
            contextPercent: contextPercent(for: session),
            contextWindow: session.contextWindow,
            cost: 0,
            linesAdded: 0,
            linesRemoved: 0,
            workingDir: session.cwd,
            sessionID: session.threadID,
            durationMs: max(0, session.updatedAt.timeIntervalSince(session.startedAt) * 1000),
            apiDurationMs: 0,
            updatedAt: session.updatedAt.timeIntervalSince1970,
            cpuUsage: 0,
            isIdle: false,
            source: .codex,
            accountID: accountID,
            accountName: accountName,
            claudeDir: claudeDir,
            rateLimits: session.rateLimits,
            tokensUsed: session.totalTokens
        )
    }

    private func syntheticPID(for id: String) -> Int {
        var value = 5381
        for byte in id.utf8 {
            value = ((value << 5) &+ value) &+ Int(byte)
        }
        return abs(value % 1_000_000) + pidOffset
    }

    private func contextPercent(for session: CodexSession) -> Int {
        guard session.contextWindow > 0 else { return 0 }
        return min(100, Int(Double(session.currentContextTokens) / Double(session.contextWindow) * 100))
    }
}
