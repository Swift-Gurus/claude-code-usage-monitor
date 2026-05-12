import Foundation

/**
 solid-name: LogURLResolving
 solid-category: abstraction
 solid-description: Contract for resolving agent log target URLs. Determines the filesystem path to a JSONL log file for a parent session or subagent. Separated from LogParser to isolate URL resolution from message parsing.
 */
protocol LogURLResolving {
    func resolveURL(agent: AgentInfo, target: LogTarget) -> URL
    func mostRecentJSONL(in dir: URL) -> URL?
}

/**
 solid-name: LogURLResolver
 solid-category: service
 solid-description: Resolves agent log targets to filesystem URLs for JSONL files. Handles both parent session and subagent path resolution using encoded project paths. Also provides most-recent-file lookup for directory-based discovery.
 */
struct LogURLResolver: LogURLResolving {
    private let pathEncoder: SessionPathEncoding
    private let fileSystem: FileSystemProviding

    init(
        pathEncoder: SessionPathEncoding = SessionPathEncoderAdapter(),
        fileSystem: FileSystemProviding = FileManager.default
    ) {
        self.pathEncoder = pathEncoder
        self.fileSystem = fileSystem
    }

    func resolveURL(agent: AgentInfo, target: LogTarget) -> URL {
        if agent.source == .codex {
            let threadID: String
            switch target {
            case .parent:
                threadID = agent.sessionID
            case .codexSession(let session):
                threadID = session.threadID
            case .subagent:
                threadID = agent.sessionID
            }

            let codexPaths = CodexPaths(homeDirectory: URL(fileURLWithPath: agent.claudeDir))
            return CodexRolloutStore(paths: codexPaths).rolloutURL(threadID: threadID)
                ?? codexPaths.sessionsDirectory
        }

        let encoded = pathEncoder.encodeProjectPath(agent.workingDir)
        let projectDir = agent.projectsDir.appendingPathComponent(encoded)

        switch target {
        case .parent:
            return projectDir.appendingPathComponent("\(agent.sessionID).jsonl")
        case .subagent(let sub):
            // Try main project dir first
            let mainURL = projectDir
                .appendingPathComponent(agent.sessionID)
                .appendingPathComponent("subagents")
                .appendingPathComponent("\(sub.agentID).jsonl")
            if fileSystem.fileExists(atPath: mainURL.path) {
                return mainURL
            }

            // Check worktree project dirs for this session's subagents
            let worktreeDirs = SessionScanner.findSubagentDirs(
                sessionID: agent.sessionID,
                workingDir: agent.workingDir,
                projectsDir: agent.projectsDir
            )
            for (subagentsDir, _) in worktreeDirs {
                let wtURL = subagentsDir.appendingPathComponent("\(sub.agentID).jsonl")
                if fileSystem.fileExists(atPath: wtURL.path) {
                    return wtURL
                }
            }

            // Bare (hook) sessions live at the project root, not in a subagents/ subdirectory
            let bareURL = projectDir.appendingPathComponent("\(sub.agentID).jsonl")
            if fileSystem.fileExists(atPath: bareURL.path) {
                return bareURL
            }

            return mainURL // last-resort fallback
        case .codexSession:
            return projectDir.appendingPathComponent("\(agent.sessionID).jsonl")
        }
    }

    func mostRecentJSONL(in dir: URL) -> URL? {
        guard let files = try? fileSystem.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        return files
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { url -> (URL, Date)? in
                let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return (url, mtime)
            }
            .max(by: { $0.1 < $1.1 })?
            .0
    }
}
