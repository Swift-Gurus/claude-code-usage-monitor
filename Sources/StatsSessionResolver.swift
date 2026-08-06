import Foundation

/**
 solid-name: StatsSessionResolving
 solid-category: abstraction
 solid-description: Contract that defines resolution of all transcript files for a session.
 */
protocol StatsSessionResolving {
    func resolveSessionFiles(sessionID: String, workingDir: String, projectsDir: URL) -> [URL]
}

/**
 solid-name: StatsSessionResolver
 solid-category: service
 solid-description: Resolves all transcript files associated with a session.
 */
struct StatsSessionResolver: StatsSessionResolving {
    private let fileSystem: FileSystemProviding
    private let pathEncoder: SessionPathEncoding
    private let directoryLocator: DirectoryLocating
    private let bareChildFileLocator: StatsBareChildFileLocating

    init(
        fileSystem: FileSystemProviding = FileManager.default,
        pathEncoder: SessionPathEncoding = SessionPathEncoderAdapter(),
        directoryLocator: DirectoryLocating = DefaultDirectoryLocator(),
        bareChildFileLocator: StatsBareChildFileLocating = DefaultStatsBareChildFileLocator()
    ) {
        self.fileSystem = fileSystem
        self.pathEncoder = pathEncoder
        self.directoryLocator = directoryLocator
        self.bareChildFileLocator = bareChildFileLocator
    }

    func resolveSessionFiles(sessionID: String, workingDir: String, projectsDir: URL) -> [URL] {
        guard !sessionID.isEmpty else { return [] }

        let projectDir = projectsDir.appendingPathComponent(pathEncoder.encodeProjectPath(workingDir))

        var files: Set<URL> = [projectDir.appendingPathComponent("\(sessionID).jsonl")]
        files.formUnion(subagentFiles(sessionID: sessionID, workingDir: workingDir, projectsDir: projectsDir))
        files.formUnion(bareChildFiles(sessionID: sessionID, projectDir: projectDir))
        return Array(files)
    }

    private func subagentFiles(sessionID: String, workingDir: String, projectsDir: URL) -> [URL] {
        directoryLocator.findSubagentDirs(sessionID: sessionID, workingDir: workingDir, projectsDir: projectsDir).flatMap { dir, _ in
            (try? fileSystem.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "jsonl" } ?? []
        }
    }

    private func bareChildFiles(sessionID: String, projectDir: URL) -> [URL] {
        bareChildFileLocator.files(parentSessionID: sessionID, in: projectDir)
    }
}
