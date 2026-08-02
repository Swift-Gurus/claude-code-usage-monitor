import Foundation

/**
 solid-name: DirectoryLocating
 solid-category: abstraction
 solid-description: Contract for locating a session's subagent directories.
 */
protocol DirectoryLocating {
    func findSubagentDirs(sessionID: String, workingDir: String, projectsDir: URL) -> [(dir: URL, worktreeName: String?)]
}

/**
 solid-name: DefaultDirectoryLocator
 solid-category: service
 solid-description: Default implementation of directory location for subagent sessions.
 */
struct DefaultDirectoryLocator: DirectoryLocating {
    func findSubagentDirs(sessionID: String, workingDir: String, projectsDir: URL) -> [(dir: URL, worktreeName: String?)] {
        SessionScanner.findSubagentDirs(sessionID: sessionID, workingDir: workingDir, projectsDir: projectsDir)
    }
}
