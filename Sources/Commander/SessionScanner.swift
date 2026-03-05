import Foundation

struct ActiveSession {
    let pid: Int
    let workingDir: String
    let jsonlURL: URL
    let sessionID: String
}

/// Discovers running Claude Code processes (including Commander/pipe-mode sessions)
/// and maps them to their JSONL conversation files.
enum SessionScanner {

    private static let projectsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")

    // Short-lived cache so multiple callers in the same reload cycle share one scan
    private static var cachedSessions: [ActiveSession] = []
    private static var cacheTime: Date = .distantPast

    /// Find all running `claude` processes and resolve their JSONL session files.
    /// Results are cached for 2 seconds to avoid redundant ps/lsof calls.
    static func findActiveSessions() -> [ActiveSession] {
        let now = Date()
        if now.timeIntervalSince(cacheTime) < 2 { return cachedSessions }

        let pidToCwd = findClaudeProcesses()
        var sessions: [ActiveSession] = []

        for (pid, cwd) in pidToCwd {
            let encoded = encodeProjectPath(cwd)
            let projectDir = projectsDir.appendingPathComponent(encoded)

            guard let (jsonlURL, sessionID) = mostRecentJSONL(in: projectDir) else { continue }

            sessions.append(ActiveSession(
                pid: pid,
                workingDir: cwd,
                jsonlURL: jsonlURL,
                sessionID: sessionID
            ))
        }

        cachedSessions = sessions
        cacheTime = now
        return sessions
    }

    // MARK: - Private

    /// Returns a dictionary of PID → working directory for `claude` processes launched by Commander.
    /// Uses PPID to identify Commander-spawned processes, then `lsof` to get CWDs.
    private static func findClaudeProcesses() -> [Int: String] {
        // Step 1: Get all processes with PID, PPID, and command
        guard let psOutput = runCommand("/bin/ps", ["-e", "-o", "pid,ppid,comm"]) else { return [:] }

        // Build a set of Commander PIDs (any process whose comm contains "Commander")
        var commanderPIDs: Set<Int> = []
        for line in psOutput.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("Commander.app") || trimmed.hasSuffix("/Commander") {
                if let pid = Int(trimmed.split(separator: " ", maxSplits: 1).first ?? "") {
                    commanderPIDs.insert(pid)
                }
            }
        }

        // Find claude processes whose parent is Commander
        let pids = psOutput.split(separator: "\n").compactMap { line -> Int? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasSuffix("/claude") || trimmed.hasSuffix(" claude") else { return nil }
            let parts = trimmed.split(separator: " ", maxSplits: 2)
            guard parts.count >= 2,
                  let pid = Int(parts[0]),
                  let ppid = Int(parts[1]),
                  commanderPIDs.contains(ppid) else { return nil }
            return pid
        }

        guard !pids.isEmpty else { return [:] }

        // Step 2: Get working directories via lsof (batch all PIDs)
        let pidArg = pids.map(String.init).joined(separator: ",")
        guard let lsofOutput = runCommand("/usr/sbin/lsof", ["-a", "-p", pidArg, "-d", "cwd", "-Fn"]) else {
            return [:]
        }

        // Parse lsof -Fn output: "p<pid>" lines followed by "n<path>" lines
        var result: [Int: String] = [:]
        var currentPID: Int?
        for line in lsofOutput.split(separator: "\n") {
            if line.hasPrefix("p") {
                currentPID = Int(line.dropFirst())
            } else if line.hasPrefix("n/"), let pid = currentPID {
                result[pid] = String(line.dropFirst())
            }
        }
        return result
    }

    /// Encode a filesystem path into the project directory name format Claude Code uses.
    /// Claude Code replaces `/`, `.`, and `_` with `-`.
    /// e.g. "/Users/foo/.ai_rules" → "-Users-foo--ai-rules"
    static func encodeProjectPath(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "_", with: "-")
    }

    /// Find the most recently modified .jsonl file in a project directory (top level only).
    private static func mostRecentJSONL(in dir: URL) -> (URL, String)? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        var best: (URL, Date)?
        for file in files where file.pathExtension == "jsonl" {
            let mod = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if best == nil || mod > best!.1 {
                best = (file, mod)
            }
        }

        guard let (url, _) = best else { return nil }
        let sessionID = url.deletingPathExtension().lastPathComponent
        return (url, sessionID)
    }

    /// Run a command and return stdout as a string, or nil on failure.
    private static func runCommand(_ path: String, _ args: [String]) -> String? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            // Read pipe BEFORE waitUntilExit to avoid deadlock when output exceeds buffer
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
