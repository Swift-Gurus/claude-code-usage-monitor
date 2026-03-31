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
public enum CommanderSupport {

    public static let defaultBaseDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/usage/commander")

    /// For backward compatibility
    public static var baseDir: URL { defaultBaseDir }

    /// Discover active Commander sessions and write `.dat`/`.agent.json` files
    /// so they appear in the standard UsageData + AgentTracker pipelines.
    ///
    /// Must be called **before** `UsageData.reload()` and `AgentTracker.reload()`
    /// so both read consistent, fresh data.

    public static func refreshFiles(accounts: [Account] = [.default]) {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFmt.string(from: Date())
        for account in accounts {
            let commanderDir = account.commanderDir
            let todayDir = commanderDir.appendingPathComponent(todayStr)
            let markerURL = commanderDir.appendingPathComponent(".last_cleanup")
            cleanupDeadPIDs(in: todayDir)
            cleanupOldData(today: todayStr, dateFmt: dateFmt, baseDir: commanderDir, markerURL: markerURL)
            writeAgentData(in: todayDir, projectsDir: account.projectsDir)

            // For accounts without statusline (no .dat files in usage/),
            // scan JSONL sessions to generate cost data from recent activity.
            // Check is cheap (directory listing) but JSONL parsing is not — cache handles it.
            let cliTodayDir = account.usageDir.appendingPathComponent(todayStr)
            let cliDatFiles = (try? FileManager.default.contentsOfDirectory(at: cliTodayDir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "dat" } ?? []
            // Only use JSONL fallback if there are NO statusline-written .dat files.
            // If statusline is installed, it writes .dat files — no need for expensive JSONL parsing.
            if cliDatFiles.isEmpty {
                writeJSONLBasedData(account: account, todayStr: todayStr)
            }
        }
    }

    /// Cache: JSONL file path → last mtime we processed. Skip re-parsing unchanged files.
    private static var jsonlMtimeCache: [String: Date] = [:]

    /// For accounts without statusline integration, scan recent JSONL files
    /// in the projects directory and generate .dat/.agent.json from them.
    private static func writeJSONLBasedData(account: Account, todayStr: String) {
        let fm = FileManager.default
        let projectsDir = account.projectsDir
        guard let projectDirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return }

        let todayDir = account.usageDir.appendingPathComponent(todayStr)
        let now = Date()

        for projectDir in projectDirs {
            guard let files = try? fm.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let mtime = attrs.contentModificationDate,
                      now.timeIntervalSince(mtime) < 86400
                else { continue }

                // Skip if file hasn't changed since last parse
                let key = file.path
                if let cached = jsonlMtimeCache[key], cached == mtime { continue }
                jsonlMtimeCache[key] = mtime

                let sessionID = file.deletingPathExtension().lastPathComponent
                let encodedPath = projectDir.lastPathComponent
                let workingDir = decodePath(encodedPath)

                guard let usage = JSONLParser.parseSession(
                    at: file,
                    sessionID: sessionID,
                    workingDir: workingDir
                ) else { continue }

                // Use a synthetic PID based on session ID hash (stable across reloads)
                let syntheticPID = abs(sessionID.hashValue % 1_000_000) + 900_000

                try? fm.createDirectory(at: todayDir, withIntermediateDirectories: true)

                let datContent = "\(usage.costUSD) \(usage.linesAdded) \(usage.linesRemoved) \(usage.displayModel)\n"
                try? datContent.write(
                    to: todayDir.appendingPathComponent("\(syntheticPID).dat"),
                    atomically: true, encoding: .utf8
                )

                let durationMs = usage.lastUpdatedAt.timeIntervalSince(usage.startedAt) * 1000
                let resolved = ClaudeModel.from(modelID: usage.model)
                let agentData = AgentFileData(
                    pid: syntheticPID,
                    model: usage.displayModel,
                    agentName: usage.agentName,
                    contextPercent: usage.contextPercent,
                    contextWindow: resolved.contextWindowSize,
                    cost: usage.costUSD,
                    linesAdded: usage.linesAdded,
                    linesRemoved: usage.linesRemoved,
                    workingDir: workingDir,
                    sessionID: sessionID,
                    durationMs: durationMs,
                    apiDurationMs: 0,
                    updatedAt: usage.lastUpdatedAt.timeIntervalSince1970
                )
                if let data = try? JSONEncoder().encode(agentData) {
                    try? data.write(
                        to: todayDir.appendingPathComponent("\(syntheticPID).agent.json"),
                        options: .atomic
                    )
                }
            }
        }
    }

    /// Best-effort decode of Claude's encoded project path back to filesystem path.
    /// Claude replaces `/`, `.`, `_` with `-`, so we restore `/` for leading `-` patterns.
    private static func decodePath(_ encoded: String) -> String {
        // The encoding replaces / . _ with -, so "-Users-foo-bar" → "/Users/foo/bar"
        // This is lossy (can't distinguish . vs _ vs /) but leading segments are always /
        var path = encoded
        if path.hasPrefix("-") {
            path = "/" + String(path.dropFirst())
        }
        path = path.replacingOccurrences(of: "-", with: "/")
        // Try to find the actual directory — walk up until we find one that exists
        let fm = FileManager.default
        if fm.fileExists(atPath: path) { return path }
        // Fallback: return the best guess
        return path
    }

    /// Remove date folders older than 3 months. Runs once per day.
    private static func cleanupOldData(today: String, dateFmt: DateFormatter, baseDir: URL, markerURL: URL) {
        let fm = FileManager.default
        let marker = markerURL
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

    private static func writeAgentData(in todayDir: URL, projectsDir: URL? = nil) {
        let fm = FileManager.default
        // SessionScanner only returns claude processes spawned by Commander (via PPID check)
        let activeSessions = SessionScanner.findActiveSessions(projectsDir: projectsDir)
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
            let datContent = "\(usage.costUSD) \(usage.linesAdded) \(usage.linesRemoved) \(usage.displayModel)\n"
            try? datContent.write(
                to: todayDir.appendingPathComponent("\(session.pid).dat"),
                atomically: true, encoding: .utf8
            )

            // Write .agent.json so the agent shows up in the UI
            let resolved = ClaudeModel.from(modelID: usage.model)
            let agentData = AgentFileData(
                pid: session.pid,
                model: usage.displayModel,
                agentName: usage.agentName,
                contextPercent: usage.contextPercent,
                contextWindow: resolved.contextWindowSize,
                cost: usage.costUSD,
                linesAdded: usage.linesAdded,
                linesRemoved: usage.linesRemoved,
                workingDir: usage.workingDir,
                sessionID: usage.sessionID,
                durationMs: durationMs,
                apiDurationMs: 0,
                updatedAt: usage.lastUpdatedAt.timeIntervalSince1970
            )
            if let data = try? JSONEncoder().encode(agentData) {
                try? data.write(
                    to: todayDir.appendingPathComponent("\(session.pid).agent.json"),
                    options: .atomic
                )
            }
        }
    }
}
