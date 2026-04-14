import Foundation

/**
 solid-name: FileSystemProviding
 solid-category: abstraction
 solid-description: Contract for file system operations used across Commander subsystems. Abstracts directory listing, creation, removal, existence checks, and attribute reading to enable testability.
 */
protocol FileSystemProviding {
    var homeDirectoryForCurrentUser: URL { get }
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
    func removeItem(at url: URL) throws
    func fileExists(atPath path: String) -> Bool
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
}

extension FileSystemProviding {
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?) throws -> [URL] {
        try contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [])
    }
}

extension FileManager: FileSystemProviding {}

/**
 solid-name: SessionFinding
 solid-category: abstraction
 solid-description: Contract for discovering active Commander-spawned Claude sessions via process scanning.
 */
protocol SessionFinding {
    func findActiveSessions(projectsDir: URL?) -> [ActiveSession]
}

/**
 solid-name: SessionScannerAdapter
 solid-category: utility
 solid-description: Adapts SessionScanner's static API to the SessionFinding protocol for dependency injection.
 */
struct SessionScannerAdapter: SessionFinding {
    func findActiveSessions(projectsDir: URL?) -> [ActiveSession] {
        SessionScanner.findActiveSessions(projectsDir: projectsDir)
    }
}

/**
 solid-name: JSONLSessionParsing
 solid-category: abstraction
 solid-description: Contract for parsing JSONL session files into aggregated usage data.
 */
protocol JSONLSessionParsing {
    func parseSession(at url: URL, sessionID: String, workingDir: String) -> SessionUsage?
}

/**
 solid-name: JSONLParserAdapter
 solid-category: utility
 solid-description: Adapts JSONLParser's static API to the JSONLSessionParsing protocol for dependency injection.
 */
struct JSONLParserAdapter: JSONLSessionParsing {
    func parseSession(at url: URL, sessionID: String, workingDir: String) -> SessionUsage? {
        JSONLParser.parseSession(at: url, sessionID: sessionID, workingDir: workingDir)
    }
}

/**
 solid-name: ModelResolving
 solid-category: abstraction
 solid-description: Contract for resolving a raw model ID string into a known ClaudeModel with display name and pricing.
 */
protocol ModelResolving {
    func resolve(modelID: String) -> ClaudeModel
}

/**
 solid-name: ClaudeModelAdapter
 solid-category: utility
 solid-description: Adapts ClaudeModel's static from(modelID:) API to the ModelResolving protocol for dependency injection.
 */
struct ClaudeModelAdapter: ModelResolving {
    func resolve(modelID: String) -> ClaudeModel {
        ClaudeModel.from(modelID: modelID)
    }
}

/**
 solid-name: ProcessLivenessChecking
 solid-category: abstraction
 solid-description: Contract for checking whether an OS process is still alive. Isolates the POSIX kill() system call behind an injectable boundary for testability.
 */
protocol ProcessLivenessChecking {
    func isAlive(pid: Int32) -> Bool
}

/**
 solid-name: POSIXProcessChecker
 solid-category: service
 solid-description: Boundary adapter wrapping the POSIX kill(pid, 0) global function to check process liveness. Encapsulates the system call behind the ProcessLivenessChecking protocol.
 */
struct POSIXProcessChecker: ProcessLivenessChecking {
    func isAlive(pid: Int32) -> Bool {
        kill(pid, 0) == 0
    }
}

/**
 solid-name: CommanderCleanupService
 solid-category: service
 solid-description: Handles maintenance tasks for Commander data: removing dead PID agent files and purging date folders older than 3 months. Separated from data writing to isolate DevOps/maintenance concerns.
 */
struct CommanderCleanupService {
    private let fileSystem: FileSystemProviding
    private let processChecker: ProcessLivenessChecking

    init(
        fileSystem: FileSystemProviding,
        processChecker: ProcessLivenessChecking = POSIXProcessChecker()
    ) {
        self.fileSystem = fileSystem
        self.processChecker = processChecker
    }

    func cleanupDeadPIDs(in dir: URL) {
        guard let files = try? fileSystem.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasSuffix(".agent.json") {
            let pidStr = file.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: ".agent", with: "")
            guard let pid = Int(pidStr) else { continue }
            if !processChecker.isAlive(pid: Int32(pid)) {
                try? fileSystem.removeItem(at: file)
            }
        }
    }

    func cleanupOldData(today: String, dateFmt: DateFormatter, baseDir: URL, markerURL: URL) {
        let marker = markerURL
        if let last = try? String(contentsOf: marker, encoding: .utf8),
           last.trimmingCharacters(in: .whitespacesAndNewlines) == today { return }

        try? fileSystem.createDirectory(at: baseDir, withIntermediateDirectories: true, attributes: nil)
        try? today.write(to: marker, atomically: true, encoding: .utf8)

        guard let cutoff = Calendar.current.date(byAdding: .month, value: -3, to: Date()),
              let dirs = try? fileSystem.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil)
        else { return }

        let cutoffStr = dateFmt.string(from: cutoff)
        for dir in dirs {
            let name = dir.lastPathComponent
            guard dateFmt.date(from: name) != nil, name < cutoffStr else { continue }
            try? fileSystem.removeItem(at: dir)
        }
    }
}

/**
 solid-name: CommanderDataWriter
 solid-category: service
 solid-description: Discovers active Commander sessions and writes .dat/.agent.json files so they appear in UsageData and AgentTracker pipelines. Also handles JSONL-based fallback for accounts without statusline integration. Separated from cleanup to isolate the data pipeline concern.
 */
struct CommanderDataWriter {
    private let fileSystem: FileSystemProviding
    private let sessionFinder: SessionFinding
    private let jsonlParser: JSONLSessionParsing
    private let modelResolver: ModelResolving

    init(
        fileSystem: FileSystemProviding,
        sessionFinder: SessionFinding,
        jsonlParser: JSONLSessionParsing,
        modelResolver: ModelResolving
    ) {
        self.fileSystem = fileSystem
        self.sessionFinder = sessionFinder
        self.jsonlParser = jsonlParser
        self.modelResolver = modelResolver
    }

    func writeAgentData(in todayDir: URL, projectsDir: URL? = nil) {
        let activeSessions = sessionFinder.findActiveSessions(projectsDir: projectsDir)
        guard !activeSessions.isEmpty else { return }

        for session in activeSessions {
            guard let usage = jsonlParser.parseSession(
                at: session.jsonlURL,
                sessionID: session.sessionID,
                workingDir: session.workingDir
            ) else { continue }

            writeSessionFiles(pid: session.pid, usage: usage, todayDir: todayDir)
        }
    }

    private func writeSessionFiles(
        pid: Int,
        usage: SessionUsage,
        todayDir: URL,
        workingDir: String? = nil,
        sessionID: String? = nil
    ) {
        try? fileSystem.createDirectory(at: todayDir, withIntermediateDirectories: true, attributes: nil)

        let datContent = "\(usage.costUSD) \(usage.linesAdded) \(usage.linesRemoved) \(usage.displayModel)\n"
        try? datContent.write(
            to: todayDir.appendingPathComponent("\(pid).dat"),
            atomically: true, encoding: .utf8
        )

        let durationMs = usage.lastUpdatedAt.timeIntervalSince(usage.startedAt) * 1000
        let resolved = modelResolver.resolve(modelID: usage.model)
        let agentData = AgentFileData(
            pid: pid,
            model: usage.displayModel,
            agentName: usage.agentName,
            contextPercent: usage.contextPercent,
            contextWindow: resolved.contextWindowSize,
            cost: usage.costUSD,
            linesAdded: usage.linesAdded,
            linesRemoved: usage.linesRemoved,
            workingDir: workingDir ?? usage.workingDir,
            sessionID: sessionID ?? usage.sessionID,
            durationMs: durationMs,
            apiDurationMs: 0,
            updatedAt: usage.lastUpdatedAt.timeIntervalSince1970
        )
        if let data = try? JSONEncoder().encode(agentData) {
            try? data.write(
                to: todayDir.appendingPathComponent("\(pid).agent.json"),
                options: .atomic
            )
        }
    }

    func writeJSONLBasedData(account: Account, todayStr: String, jsonlMtimeCache: inout [String: Date]) {
        let projectsDir = account.projectsDir
        guard let projectDirs = try? fileSystem.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return }

        let todayDir = account.usageDir.appendingPathComponent(todayStr)
        let now = Date()

        for projectDir in projectDirs {
            guard let files = try? fileSystem.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let mtime = attrs.contentModificationDate,
                      now.timeIntervalSince(mtime) < 86400
                else { continue }

                let key = file.path
                if let cached = jsonlMtimeCache[key], cached == mtime { continue }
                jsonlMtimeCache[key] = mtime

                let sessionID = file.deletingPathExtension().lastPathComponent

                let workingDir: String
                if let data = try? Data(contentsOf: file),
                   let content = String(data: data, encoding: .utf8),
                   let firstLine = content.split(separator: "\n").first,
                   let lineData = firstLine.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                   let cwd = json["cwd"] as? String {
                    workingDir = cwd
                } else {
                    continue
                }

                guard let usage = jsonlParser.parseSession(
                    at: file,
                    sessionID: sessionID,
                    workingDir: workingDir
                ) else { continue }

                let syntheticPID = abs(sessionID.hashValue % 1_000_000) + 900_000

                writeSessionFiles(
                    pid: syntheticPID,
                    usage: usage,
                    todayDir: todayDir,
                    workingDir: workingDir,
                    sessionID: sessionID
                )
            }
        }
    }
}

/**
 solid-name: CommanderSupport
 solid-category: service
 solid-stack: [structured-concurrency]
 solid-description: Facade for Commander (pipe-mode) session support. Coordinates cleanup of dead PIDs and old data with discovery and writing of active session data. Delegates to CommanderCleanupService and CommanderDataWriter subsystems.
 */
public enum CommanderSupport {
    static func defaultBaseDir(fileSystem: FileSystemProviding = FileManager.default) -> URL {
        fileSystem.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/usage/commander")
    }

    public static var baseDir: URL { defaultBaseDir() }

    private static var jsonlMtimeCache: [String: Date] = [:]

    public static func refreshFiles(accounts: [Account] = [.default]) {
        refreshFiles(
            accounts: accounts,
            fileSystem: FileManager.default,
            sessionFinder: SessionScannerAdapter(),
            jsonlParser: JSONLParserAdapter(),
            modelResolver: ClaudeModelAdapter()
        )
    }

    static func refreshFiles(
        accounts: [Account],
        fileSystem: FileSystemProviding,
        sessionFinder: SessionFinding,
        jsonlParser: JSONLSessionParsing,
        modelResolver: ModelResolving
    ) {
        let cleanup = CommanderCleanupService(fileSystem: fileSystem, processChecker: POSIXProcessChecker())
        let writer = CommanderDataWriter(
            fileSystem: fileSystem,
            sessionFinder: sessionFinder,
            jsonlParser: jsonlParser,
            modelResolver: modelResolver
        )

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFmt.string(from: Date())
        for account in accounts {
            let commanderDir = account.commanderDir
            let todayDir = commanderDir.appendingPathComponent(todayStr)
            let markerURL = commanderDir.appendingPathComponent(".last_cleanup")
            cleanup.cleanupDeadPIDs(in: todayDir)
            cleanup.cleanupOldData(today: todayStr, dateFmt: dateFmt, baseDir: commanderDir, markerURL: markerURL)
            writer.writeAgentData(in: todayDir, projectsDir: account.projectsDir)

            let cliTodayDir = account.usageDir.appendingPathComponent(todayStr)
            let cliDatFiles = (try? fileSystem.contentsOfDirectory(at: cliTodayDir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "dat" } ?? []
            if cliDatFiles.isEmpty {
                writer.writeJSONLBasedData(account: account, todayStr: todayStr, jsonlMtimeCache: &jsonlMtimeCache)
            }
        }
    }
}
