import Foundation

/**
 solid-name: SessionWorkingDirCollecting
 solid-category: abstraction
 solid-description: Contract for discovering session identifiers and their working directories for a specified time period.
 */
protocol SessionWorkingDirCollecting {
    func collect(under root: URL, since monthStart: Date) -> [String: String]
}

/**
 solid-name: SessionWorkingDirCollector
 solid-category: service
 solid-description: Collects session identifiers and their working directories from usage data for a specified time period.
 */
struct SessionWorkingDirCollector: SessionWorkingDirCollecting {
    private let fileSystem: FileSystemProviding

    init(fileSystem: FileSystemProviding = FileManager.default) {
        self.fileSystem = fileSystem
    }

    func collect(under root: URL, since monthStart: Date) -> [String: String] {
        var result: [String: String] = [:]
        let calendar = Calendar.current
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        guard let dateDirs = try? fileSystem.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return result
        }

        for dateDir in dateDirs {
            guard let dirDate = dateFmt.date(from: dateDir.lastPathComponent),
                  calendar.startOfDay(for: dirDate) >= monthStart
            else { continue }

            guard let files = try? fileSystem.contentsOfDirectory(at: dateDir, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.lastPathComponent.hasSuffix(".agent.json") {
                guard let (sessionID, workingDir) = readSessionWorkingDir(from: file) else { continue }
                result[sessionID] = workingDir
            }
        }
        return result
    }

    private func readSessionWorkingDir(from file: URL) -> (sessionID: String, workingDir: String)? {
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessionID = json["session_id"] as? String, !sessionID.isEmpty,
              let workingDir = json["working_dir"] as? String, !workingDir.isEmpty
        else { return nil }
        return (sessionID, workingDir)
    }
}
