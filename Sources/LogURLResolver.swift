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
        let encoded = pathEncoder.encodeProjectPath(agent.workingDir)
        let projectDir = agent.projectsDir.appendingPathComponent(encoded)

        switch target {
        case .parent:
            return projectDir.appendingPathComponent("\(agent.sessionID).jsonl")
        case .subagent(let sub):
            return projectDir
                .appendingPathComponent(agent.sessionID)
                .appendingPathComponent("subagents")
                .appendingPathComponent("\(sub.agentID).jsonl")
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
