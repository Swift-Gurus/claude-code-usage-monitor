import Foundation

/// Facade for Commander (pipe-mode) session support.
///
/// Commander runs Claude Code with `-p --output-format=stream-json`, which skips
/// the statusline command entirely. This module discovers those sessions via process
/// scanning and writes `.dat`/`.agent.json` files into a **separate** `commander/`
/// subfolder so they never collide with statusline-written files.
///
/// **Depends on undocumented Claude Code internals** (JSONL format, project directory
/// layout). May break on Claude Code updates.
///
/// Data layout:
/// ```
/// ~/.claude/usage/
/// ├── YYYY-MM-DD/              ← CLI (statusline writes here)
/// └── commander/
///     └── YYYY-MM-DD/          ← Commander (this module writes here)
/// ```
///
/// To remove Commander support entirely:
/// 1. Delete the `Sources/Commander/` folder
/// 2. Remove the `CommanderSupport.refreshFiles()` call in `ClaudeUsageBarApp.swift`
/// 3. Remove `commanderDir` references in `UsageData.swift` and `AgentTracker.swift`
/// 4. Optionally remove the poll timer in `UsageMonitor.swift`
/// 5. Optionally `rm -rf ~/.claude/usage/commander/`
enum CommanderSupport {

    static let baseDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/usage/commander")

    /// Discover active Commander sessions and write `.dat`/`.agent.json` files
    /// so they appear in the standard UsageData + AgentTracker pipelines.
    ///
    /// Must be called **before** `UsageData.reload()` and `AgentTracker.reload()`
    /// so both read consistent, fresh data.
    static func refreshFiles() {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let todayDir = baseDir.appendingPathComponent(dateFmt.string(from: Date()))
        writeAgentData(in: todayDir)
    }

    private static func writeAgentData(in todayDir: URL) {
        let fm = FileManager.default
        // SessionScanner only returns claude processes spawned by Commander (via PPID check)
        let activeSessions = SessionScanner.findActiveSessions()
        guard !activeSessions.isEmpty else { return }

        for session in activeSessions {
            guard let usage = JSONLParser.parseSession(
                at: session.jsonlURL,
                sessionID: session.sessionID,
                workingDir: session.workingDir
            ) else { continue }

            let durationMs = usage.lastUpdatedAt.timeIntervalSince(usage.startedAt) * 1000

            try? fm.createDirectory(at: todayDir, withIntermediateDirectories: true)

            // Write .dat so UsageData aggregates this session's cost
            let datContent = "\(usage.costUSD) 0 0\n"
            try? datContent.write(
                to: todayDir.appendingPathComponent("\(session.pid).dat"),
                atomically: true, encoding: .utf8
            )

            // Write .agent.json so the agent shows up in the UI
            let json: [String: Any] = [
                "pid": session.pid,
                "model": usage.displayModel,
                "agent_name": usage.agentName,
                "context_pct": usage.contextPercent,
                "cost": usage.costUSD,
                "lines_added": 0,
                "lines_removed": 0,
                "working_dir": usage.workingDir,
                "session_id": usage.sessionID,
                "duration_ms": durationMs,
                "api_duration_ms": 0,
                "updated_at": Int(Date().timeIntervalSince1970)
            ]
            if let data = try? JSONSerialization.data(withJSONObject: json) {
                try? data.write(
                    to: todayDir.appendingPathComponent("\(session.pid).agent.json"),
                    options: .atomic
                )
            }
        }
    }
}
