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
    private static let cleanupMarkerURL = baseDir.appendingPathComponent(".last_cleanup")

    static func refreshFiles() {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFmt.string(from: Date())
        let todayDir = baseDir.appendingPathComponent(todayStr)
        cleanupDeadPIDs(in: todayDir)
        cleanupOldData(today: todayStr, dateFmt: dateFmt)
        writeAgentData(in: todayDir)
    }

    /// Remove date folders older than 3 months. Runs once per day.
    private static func cleanupOldData(today: String, dateFmt: DateFormatter) {
        let fm = FileManager.default
        let marker = cleanupMarkerURL
        if let last = try? String(contentsOf: marker, encoding: .utf8),
           last.trimmingCharacters(in: .whitespacesAndNewlines) == today { return }

        try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        try? today.write(to: marker, atomically: true, encoding: .utf8)

        guard let cutoff = Calendar.current.date(byAdding: .month, value: -3, to: Date()),
              let dirs = try? fm.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil)
        else { return }

        let cutoffStr = dateFmt.string(from: cutoff)
        for dir in dirs {
            let name = dir.lastPathComponent
            guard dateFmt.date(from: name) != nil, name < cutoffStr else { continue }
            try? fm.removeItem(at: dir)
        }
    }

    /// Remove .agent.json for PIDs that are no longer running.
    /// .dat files are kept for cost history (daily/weekly/monthly totals).
    private static func cleanupDeadPIDs(in dir: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasSuffix(".agent.json") {
            let pidStr = file.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: ".agent", with: "")
            guard let pid = Int(pidStr) else { continue }
            if kill(Int32(pid), 0) != 0 {
                try? fm.removeItem(at: file)
            }
        }
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
            let datContent = "\(usage.costUSD) 0 0 \(usage.displayModel)\n"
            try? datContent.write(
                to: todayDir.appendingPathComponent("\(session.pid).dat"),
                atomically: true, encoding: .utf8
            )

            // Write .agent.json so the agent shows up in the UI
            let resolved = ClaudeModel.from(modelID: usage.model)
            let json: [String: Any] = [
                "pid": session.pid,
                "model": usage.displayModel,
                "agent_name": usage.agentName,
                "context_pct": usage.contextPercent,
                "context_window": resolved.contextWindowSize,
                "cost": usage.costUSD,
                "lines_added": 0,
                "lines_removed": 0,
                "working_dir": usage.workingDir,
                "session_id": usage.sessionID,
                "duration_ms": durationMs,
                "api_duration_ms": 0,
                "updated_at": Int(usage.lastUpdatedAt.timeIntervalSince1970)
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
