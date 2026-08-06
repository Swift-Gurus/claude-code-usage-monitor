import Foundation

/**
 solid-name: BareChildLocating
 solid-category: abstraction
 solid-description: Contract for discovering bare child sessions linked to a parent session.
 */
protocol BareChildLocating {
    func parseBareChildren(parentSessionID: String, in projectDir: URL) -> [SubagentInfo]
}

/**
 solid-name: DefaultBareChildLocator
 solid-category: service
 solid-description: Discovers bare child sessions linked to a parent session.
 */
struct DefaultBareChildLocator: BareChildLocating {
    func parseBareChildren(parentSessionID: String, in projectDir: URL) -> [SubagentInfo] {
        JSONLParser.parseBareChildren(parentSessionID: parentSessionID, in: projectDir)
    }
}

/// Stats only need each matching transcript URL, not the fully calculated subagent
/// model/cost details. This locator indexes a project directory once and reuses the
/// parent-to-child mapping for every active parent session in that directory.
protocol StatsBareChildFileLocating {
    func files(parentSessionID: String, in projectDir: URL) -> [URL]
}

final class DefaultStatsBareChildFileLocator: StatsBareChildFileLocating {
    private struct CacheEntry {
        let directoryModifiedAt: Date?
        let fileCount: Int
        let filesByParent: [String: [URL]]
    }

    private var cacheByProject: [URL: CacheEntry] = [:]

    func files(parentSessionID: String, in projectDir: URL) -> [URL] {
        let directoryModifiedAt = try? projectDir.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        let files = (try? FileManager.default.contentsOfDirectory(
            at: projectDir, includingPropertiesForKeys: nil
        )) ?? []
        if let cached = cacheByProject[projectDir],
           cached.directoryModifiedAt == directoryModifiedAt,
           cached.fileCount == files.count {
            return cached.filesByParent[parentSessionID] ?? []
        }

        let indexed = indexBareChildren(in: files)
        cacheByProject[projectDir] = CacheEntry(
            directoryModifiedAt: directoryModifiedAt,
            fileCount: files.count,
            filesByParent: indexed
        )
        return indexed[parentSessionID] ?? []
    }

    private func indexBareChildren(in files: [URL]) -> [String: [URL]] {
        var indexed: [String: [URL]] = [:]
        for file in files where file.pathExtension == "jsonl" {
            guard let parentID = spawnedByParentID(in: file) else { continue }
            indexed[parentID, default: []].append(file)
        }
        return indexed
    }

    private func spawnedByParentID(in file: URL) -> String? {
        guard let prefix = readJSONLPrefix(at: file) else { return nil }
        for line in prefix.split(separator: "\n", omittingEmptySubsequences: true).prefix(30) {
            guard let data = line.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  raw["type"] as? String == "user"
            else { continue }

            guard raw["entrypoint"] as? String == "sdk-cli" else { return nil }
            guard let message = raw["message"] as? [String: Any],
                  let content = message["content"] as? String
            else { return nil }

            let marker = "# spawned-by: "
            guard content.hasPrefix(marker) else { return nil }
            let firstLine = content.dropFirst(marker.count).prefix { !$0.isNewline }
            let parentID = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return parentID.isEmpty ? nil : parentID
        }
        return nil
    }
}
