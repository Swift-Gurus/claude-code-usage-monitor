import Foundation
import AppKit

/// Discovers active Claude Desktop app sessions from
/// `~/Library/Application Support/Claude/claude-code-sessions/`.
/// Each session JSON has a `cliSessionId` that maps to JSONL files in `~/.claude/projects/`.
public enum DesktopAppScanner {

    private static let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")

    /// A desktop app session with metadata from the session JSON.
    public struct DesktopSession {
        public let cliSessionID: String   // maps to JSONL in .claude/projects/
        public let cwd: String            // working directory
        public let originCwd: String      // original project root (for worktrees)
        public let model: String          // e.g. "claude-opus-4-7[1m]"
        public let title: String          // session title
        public let worktreeName: String   // e.g. "friendly-bose"
        public let branch: String         // e.g. "claude/friendly-bose"
        public let lastActivityAt: Date
    }

    /// Scan for active desktop app sessions.
    /// Shows all non-archived sessions that have a JSONL file, as long as Claude.app is running.
    public static func findActiveSessions() -> [DesktopSession] {
        guard isClaudeAppRunning() else { return [] }

        let fm = FileManager.default
        guard let tabDirs = try? fm.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var sessions: [DesktopSession] = []

        for tabDir in tabDirs {
            guard let projectDirs = try? fm.contentsOfDirectory(at: tabDir, includingPropertiesForKeys: nil) else { continue }
            for projectDir in projectDirs {
                guard let files = try? fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil) else { continue }
                for file in files where file.pathExtension == "json" {
                    guard let session = parseSessionJSON(at: file) else { continue }
                    if hasJSONL(session: session) {
                        sessions.append(session)
                    }
                }
            }
        }

        return sessions
    }

    // MARK: - Private

    private static func parseSessionJSON(at url: URL) -> DesktopSession? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        if json["isArchived"] as? Bool == true { return nil }

        guard let cliSessionID = json["cliSessionId"] as? String, !cliSessionID.isEmpty else { return nil }
        let cwd = json["cwd"] as? String ?? ""
        guard !cwd.isEmpty else { return nil }

        let lastActivityMs = json["lastActivityAt"] as? Double ?? 0
        let lastActivity = Date(timeIntervalSince1970: lastActivityMs / 1000)

        return DesktopSession(
            cliSessionID: cliSessionID,
            cwd: cwd,
            originCwd: json["originCwd"] as? String ?? cwd,
            model: json["model"] as? String ?? "",
            title: json["title"] as? String ?? "",
            worktreeName: json["worktreeName"] as? String ?? "",
            branch: json["branch"] as? String ?? "",
            lastActivityAt: lastActivity
        )
    }

    private static func hasJSONL(session: DesktopSession) -> Bool {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let encoded = SessionScanner.encodeProjectPath(session.cwd)
        let jsonlURL = projectsDir
            .appendingPathComponent(encoded)
            .appendingPathComponent("\(session.cliSessionID).jsonl")
        return FileManager.default.fileExists(atPath: jsonlURL.path)
    }

    /// Use NSWorkspace to check if Claude.app is running — no subprocess needed.
    private static func isClaudeAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.anthropic.claudefordesktop"
        }
    }
}
