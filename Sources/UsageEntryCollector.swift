import Foundation

/**
 solid-name: CollectedEntries
 solid-category: model
 solid-description: Value type holding the results of a filesystem scan for usage data. Contains parsed .dat entries, model transition histories, and subagent per-model stats collected from date directories.
 */
struct CollectedEntries {
    var entries: [UsageData.DatEntry] = []
    var histories: [String: [(cost: Double, la: Int, lr: Int, model: String)]] = [:]
    var subagents: [String: [String: SourceModelStats]] = [:]
}

/**
 solid-name: UsageEntryCollecting
 solid-category: abstraction
 solid-description: Contract for collecting usage entries from filesystem directories. Scans date-organized directories for .dat, .models, .agent.json, .project, and .subagents.json files and returns parsed results.
 */
protocol UsageEntryCollecting {
    func collectEntries(
        under root: URL,
        source: AgentSource,
        since monthStart: Date,
        accountID: UUID
    ) -> CollectedEntries
}

/**
 solid-name: UsageEntryCollector
 solid-category: crud
 solid-description: Scans date-organized usage directories for .dat files and associated metadata (.models, .agent.json, .project, .subagents.json). Parses and aggregates them into DatEntry arrays with model histories and subagent stats. Injects FileSystemProviding to replace direct FileManager.default usage.
 */
struct UsageEntryCollector: UsageEntryCollecting {
    private let fileSystem: FileSystemProviding

    init(fileSystem: FileSystemProviding = FileManager.default) {
        self.fileSystem = fileSystem
    }

    func collectEntries(
        under root: URL,
        source: AgentSource,
        since monthStart: Date,
        accountID: UUID
    ) -> CollectedEntries {
        var result = CollectedEntries()
        let calendar = Calendar.current
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        guard let dateDirs = try? fileSystem.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else { return result }

        for dateDir in dateDirs {
            let dirName = dateDir.lastPathComponent
            guard let dirDate = dateFmt.date(from: dirName) else { continue }
            let dirDay = calendar.startOfDay(for: dirDate)

            guard dirDay >= monthStart else { continue }

            guard let files = try? fileSystem.contentsOfDirectory(
                at: dateDir, includingPropertiesForKeys: nil
            ) else { continue }

            var pidToProject: [String: String] = [:]
            for file in files where file.pathExtension == "project" {
                guard let raw = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let pid = file.deletingPathExtension().lastPathComponent
                let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                pidToProject[pid] = (path as NSString).lastPathComponent
            }

            var pidToSession: [String: String] = [:]
            for file in files where file.lastPathComponent.hasSuffix(".agent.json") {
                let pid = file.lastPathComponent
                    .replacingOccurrences(of: ".agent.json", with: "")
                guard let data = try? Data(contentsOf: file),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let sid = json["session_id"] as? String, !sid.isEmpty else { continue }
                pidToSession[pid] = sid
            }

            for file in files where file.pathExtension == "dat" {
                guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let parts = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: " ")

                let pid = file.deletingPathExtension().lastPathComponent
                let cost = Double(parts.first ?? "0") ?? 0
                let la = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
                let lr = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0
                let model = parts.count > 3 ? parts[3...].joined(separator: " ") : ""

                result.entries.append(UsageData.DatEntry(
                    pid: pid, day: dirDay, cost: cost, absoluteCost: cost,
                    linesAdded: la, linesRemoved: lr,
                    model: model, source: source,
                    project: pidToProject[pid] ?? "",
                    sessionID: pidToSession[pid] ?? "",
                    accountID: accountID
                ))

                let modelsFile = dateDir.appendingPathComponent("\(pid).models")
                if let modelsContent = try? String(contentsOf: modelsFile, encoding: .utf8) {
                    let transitions = modelsContent.split(separator: "\n").compactMap { line -> (cost: Double, la: Int, lr: Int, model: String)? in
                        let cols = line.split(separator: "\t", maxSplits: 3)
                        guard cols.count >= 4 else { return nil }
                        return (
                            cost: Double(cols[0]) ?? 0,
                            la: Int(cols[1]) ?? 0,
                            lr: Int(cols[2]) ?? 0,
                            model: String(cols[3])
                        )
                    }
                    if transitions.count > 1 {
                        result.histories["\(pid)\t\(source.rawValue)"] = transitions
                    }
                }

                let subagentsFile = dateDir.appendingPathComponent("\(pid).subagents.json")
                if let subData = try? Data(contentsOf: subagentsFile),
                   let subMap = try? JSONDecoder().decode([String: SourceModelStats].self, from: subData),
                   !subMap.isEmpty {
                    result.subagents["\(pid)\t\(source.rawValue)"] = subMap
                }
            }
        }
        return result
    }
}
