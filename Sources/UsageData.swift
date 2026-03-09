import Foundation

public struct SourceModelStats: Codable {
    public var cost: Double = 0
    public var linesAdded: Int = 0
    public var linesRemoved: Int = 0

    public init(cost: Double = 0, linesAdded: Int = 0, linesRemoved: Int = 0) {
        self.cost = cost
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
    }
}

public struct ProjectStats {
    public var main = SourceModelStats()
    public var subagents = SourceModelStats()

    public init(main: SourceModelStats = SourceModelStats(), subagents: SourceModelStats = SourceModelStats()) {
        self.main = main
        self.subagents = subagents
    }
}

public struct SourceStats {
    public var total = SourceModelStats()
    public var byModel: [String: SourceModelStats] = [:]
    public var subagentsByModel: [String: SourceModelStats] = [:]
    public var byProject: [String: ProjectStats] = [:]

    public init(
        total: SourceModelStats = SourceModelStats(),
        byModel: [String: SourceModelStats] = [:],
        subagentsByModel: [String: SourceModelStats] = [:],
        byProject: [String: ProjectStats] = [:]
    ) {
        self.total = total
        self.byModel = byModel
        self.subagentsByModel = subagentsByModel
        self.byProject = byProject
    }
}

public struct PeriodStats {
    public var cost: Double = 0
    public var linesAdded: Int = 0
    public var linesRemoved: Int = 0
    public var cli = SourceStats()
    public var commander = SourceStats()

    public init(cost: Double = 0, linesAdded: Int = 0, linesRemoved: Int = 0, cli: SourceStats = SourceStats(), commander: SourceStats = SourceStats()) {
        self.cost = cost
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.cli = cli
        self.commander = commander
    }
}

@Observable
public final class UsageData {
    public var day = PeriodStats()
    public var week = PeriodStats()
    public var month = PeriodStats()

    private let usageDir: URL
    private let includeCommander: Bool

    /// Model transition history per PID. Key: "{pid}\t{source}".
    /// Value: sorted list of (cost, linesAdded, linesRemoved, model) at each switch point.
    private var modelHistories: [String: [(cost: Double, la: Int, lr: Int, model: String)]] = [:]

    /// Subagent per-model stats per PID. Key: "{pid}\t{source}".
    private var subagentStats: [String: [String: SourceModelStats]] = [:]

    public init() {
        usageDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/usage")
        includeCommander = true
        reload()
    }

    /// Test-only initializer with custom usage directory.
    init(testUsageDir: URL, includeCommander: Bool = false) {
        usageDir = testUsageDir
        self.includeCommander = includeCommander
        reload()
    }

    /// A single .dat entry with its metadata.
    private struct DatEntry {
        let pid: String
        let day: Date       // start of day for the folder
        let cost: Double         // period-specific cost (may be incremental after dedup)
        let absoluteCost: Double // always the raw cumulative .dat value
        let linesAdded: Int
        let linesRemoved: Int
        let model: String
        let source: AgentSource
        let project: String      // short project name from {pid}.project file, empty if unknown
        let sessionID: String    // from .agent.json if available, empty otherwise
    }

    public func reload() {
        let calendar = Calendar.current
        let now = Date()

        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        // Collect entries from one extra day before monthStart so we have baseline
        // values for sessions that span the month boundary. Without this, long-running
        // sessions would have no `prev` entry and their full cumulative cost would be
        // attributed to the current period.
        let collectSince = calendar.date(byAdding: .day, value: -1, to: monthStart)!
        var entries: [DatEntry] = []
        var histories: [String: [(cost: Double, la: Int, lr: Int, model: String)]] = [:]
        var subagents: [String: [String: SourceModelStats]] = [:]
        collectEntries(under: usageDir, source: .cli, since: collectSince, into: &entries, histories: &histories, subagents: &subagents)
        if includeCommander {
            let commanderDir = usageDir.appendingPathComponent("commander")
            collectEntries(under: commanderDir, source: .commander, since: collectSince, into: &entries, histories: &histories, subagents: &subagents)
        }
        modelHistories = histories
        subagentStats = subagents

        // Deduplicate: .dat stores cumulative session cost, so a PID spanning multiple days
        // has entries in each day's folder. Keep only the latest day per PID — that has the
        // most up-to-date cumulative cost.
        // For "today" specifically, subtract the previous day's value to get incremental cost.
        // Key includes source to avoid CLI/Commander PID collisions for the same project.
        //
        // Session-aware dedup: Claude Code may restart its process (new PID) while keeping the
        // same session (same JSONL file / session_id). Multiple PIDs then write .dat files with
        // the same cumulative cost, inflating totals. We merge PIDs that share a session_id,
        // and also detect exact-content duplicates as a fallback for PIDs without .agent.json.

        // Step 1: Build PID → sessionID map from entries (propagate across days for same PID)
        var pidSessionMap: [String: String] = [:]  // "PID\tsource" → sessionID
        for entry in entries where !entry.sessionID.isEmpty {
            let pidKey = "\(entry.pid)\t\(entry.source.rawValue)"
            pidSessionMap[pidKey] = entry.sessionID
        }

        // Step 2: Build per-PID latest/previous as before
        var latestByPID: [String: DatEntry] = [:]
        var previousByPID: [String: DatEntry] = [:]

        for entry in entries.sorted(by: { $0.day < $1.day }) {
            let key = "\(entry.pid)\t\(entry.source.rawValue)"
            if let existing = latestByPID[key] {
                previousByPID[key] = existing
            }
            latestByPID[key] = entry
        }

        // Step 3: Exact-content duplicate detection.
        // If two PIDs have identical (cost, linesAdded, linesRemoved, model) on the same day,
        // they almost certainly represent the same session under different PIDs.
        // Keep the one with a prior-day entry (for proper incremental calculation),
        // or the one with a known sessionID.
        var mergedKeys: Set<String> = []

        for (pidKey, entry) in latestByPID {
            guard !mergedKeys.contains(pidKey) else { continue }
            for (otherKey, otherEntry) in latestByPID where otherKey > pidKey && !mergedKeys.contains(otherKey) {
                guard entry.day == otherEntry.day,
                      entry.source == otherEntry.source,
                      abs(entry.cost - otherEntry.cost) < 0.001,
                      entry.linesAdded == otherEntry.linesAdded,
                      entry.linesRemoved == otherEntry.linesRemoved else { continue }
                // Duplicate found — keep the one that has a previousByPID entry or sessionID
                let thisHasPrev = previousByPID[pidKey] != nil
                let otherHasPrev = previousByPID[otherKey] != nil
                let thisHasSession = pidSessionMap[pidKey] != nil
                let otherHasSession = pidSessionMap[otherKey] != nil
                if (otherHasPrev && !thisHasPrev) || (otherHasSession && !thisHasSession) {
                    mergedKeys.insert(pidKey)
                } else {
                    mergedKeys.insert(otherKey)
                }
            }
        }

        for key in mergedKeys {
            latestByPID.removeValue(forKey: key)
            previousByPID.removeValue(forKey: key)
        }

        // Step 4: Merge PIDs that share a sessionID — keep highest-cost latest, earliest previous.
        // This handles the case where the same session restarts under a new PID with a higher
        // cumulative cost (not byte-identical, so Step 3 doesn't catch it).
        var sessionToCanonical: [String: String] = [:]  // "sessionID\tsource" → canonical PID key

        for (pidKey, entry) in latestByPID {
            guard let sid = pidSessionMap[pidKey], !sid.isEmpty else { continue }
            let sessionKey = "\(sid)\t\(entry.source.rawValue)"

            if let canonicalKey = sessionToCanonical[sessionKey] {
                let canonicalLatest = latestByPID[canonicalKey]!
                // Keep the PID with the highest cost as the canonical latest
                let (winnerKey, loserKey) = entry.cost >= canonicalLatest.cost
                    ? (pidKey, canonicalKey)
                    : (canonicalKey, pidKey)
                let loserLatest = latestByPID[loserKey]!

                // The previous for the session is the earliest entry across all PIDs
                let winnerPrev = previousByPID[winnerKey]
                let loserPrev = previousByPID[loserKey]
                let candidates = [winnerPrev, loserPrev, loserLatest].compactMap { $0 }
                let earliestPrev = candidates.min(by: { $0.day < $1.day })
                if let ep = earliestPrev, ep.day < latestByPID[winnerKey]!.day {
                    previousByPID[winnerKey] = ep
                }

                // Merge subagent/model-history data: prefer winner's but keep loser's if winner has none
                if modelHistories[winnerKey] == nil, let loserHist = modelHistories[loserKey] {
                    modelHistories[winnerKey] = loserHist
                }
                if subagentStats[winnerKey] == nil, let loserSubs = subagentStats[loserKey] {
                    subagentStats[winnerKey] = loserSubs
                }

                mergedKeys.insert(loserKey)
                sessionToCanonical[sessionKey] = winnerKey
            } else {
                sessionToCanonical[sessionKey] = pidKey
            }
        }

        // Remove session-merged duplicates
        for key in mergedKeys {
            latestByPID.removeValue(forKey: key)
            previousByPID.removeValue(forKey: key)
        }

        var d = PeriodStats()
        var w = PeriodStats()
        var m = PeriodStats()

        for (key, latest) in latestByPID {
            let prev = previousByPID[key]

            // Month: use incremental if session spans from before monthStart
            if latest.day >= monthStart {
                if let prev, prev.day < monthStart {
                    let incremental = incrementalEntry(latest: latest, previous: prev)
                    accumulate(incremental, into: &m)
                } else {
                    accumulate(latest, into: &m)
                }
            }

            // Week: use incremental if session spans from before weekStart
            if latest.day >= weekStart {
                if let prev, prev.day < weekStart {
                    let incremental = incrementalEntry(latest: latest, previous: prev)
                    accumulate(incremental, into: &w)
                } else if let prev, prev.day >= weekStart {
                    let incremental = incrementalEntry(latest: latest, previous: prev)
                    accumulate(incremental, into: &w)
                } else {
                    accumulate(latest, into: &w)
                }
            }

            // Today: incremental cost (subtract yesterday's value if session spans midnight)
            if latest.day == today {
                if let prev, prev.day < today {
                    let incremental = incrementalEntry(latest: latest, previous: prev)
                    accumulate(incremental, into: &d)
                } else {
                    accumulate(latest, into: &d)
                }
            }
        }

        day = d; week = w; month = m
    }

    private func incrementalEntry(latest: DatEntry, previous: DatEntry) -> DatEntry {
        DatEntry(
            pid: latest.pid,
            day: latest.day,
            cost: max(0, latest.cost - previous.cost),
            absoluteCost: latest.cost, // preserve raw .dat total for model breakdown
            linesAdded: max(0, latest.linesAdded - previous.linesAdded),
            linesRemoved: max(0, latest.linesRemoved - previous.linesRemoved),
            model: latest.model,
            source: latest.source,
            project: latest.project,
            sessionID: latest.sessionID
        )
    }

    private func accumulate(_ entry: DatEntry, into p: inout PeriodStats) {
        p.cost += entry.cost
        p.linesAdded += entry.linesAdded
        p.linesRemoved += entry.linesRemoved

        let kp: WritableKeyPath<PeriodStats, SourceStats> =
            entry.source == .cli ? \.cli : \.commander
        p[keyPath: kp].total.cost += entry.cost
        p[keyPath: kp].total.linesAdded += entry.linesAdded
        p[keyPath: kp].total.linesRemoved += entry.linesRemoved

        // Compute subagent totals first — .dat cost already includes subagent costs,
        // so we must subtract them before distributing across main-session models
        // and per-project main stats to avoid double-counting.
        let subagentKey = "\(entry.pid)\t\(entry.source.rawValue)"
        var subagentTotal = SourceModelStats()
        if let subs = subagentStats[subagentKey] {
            for (model, stats) in subs {
                p[keyPath: kp].subagentsByModel[model, default: SourceModelStats()].cost += stats.cost
                p[keyPath: kp].subagentsByModel[model, default: SourceModelStats()].linesAdded += stats.linesAdded
                p[keyPath: kp].subagentsByModel[model, default: SourceModelStats()].linesRemoved += stats.linesRemoved
                subagentTotal.cost += stats.cost
                subagentTotal.linesAdded += stats.linesAdded
                subagentTotal.linesRemoved += stats.linesRemoved
            }
        }

        // Main-session cost/lines excluding subagent contribution
        let mainCost = max(0, entry.cost - subagentTotal.cost)
        let mainLA = max(0, entry.linesAdded - subagentTotal.linesAdded)
        let mainLR = max(0, entry.linesRemoved - subagentTotal.linesRemoved)

        // Distribute main-session cost across models using transition history if available
        let historyKey = "\(entry.pid)\t\(entry.source.rawValue)"
        if let history = modelHistories[historyKey], history.count > 1 {
            let breakdown = modelBreakdown(history: history,
                                           absoluteCost: entry.absoluteCost - subagentTotal.cost,
                                           periodCost: mainCost,
                                           totalLA: mainLA, totalLR: mainLR)
            for (model, stats) in breakdown {
                p[keyPath: kp].byModel[model, default: SourceModelStats()].cost += stats.cost
                p[keyPath: kp].byModel[model, default: SourceModelStats()].linesAdded += stats.linesAdded
                p[keyPath: kp].byModel[model, default: SourceModelStats()].linesRemoved += stats.linesRemoved
            }
        } else if !entry.model.isEmpty {
            p[keyPath: kp].byModel[entry.model, default: SourceModelStats()].cost += mainCost
            p[keyPath: kp].byModel[entry.model, default: SourceModelStats()].linesAdded += mainLA
            p[keyPath: kp].byModel[entry.model, default: SourceModelStats()].linesRemoved += mainLR
        }

        // Aggregate by project — main stats exclude subagent costs to avoid double-counting
        if !entry.project.isEmpty {
            p[keyPath: kp].byProject[entry.project, default: ProjectStats()].main.cost += mainCost
            p[keyPath: kp].byProject[entry.project, default: ProjectStats()].main.linesAdded += mainLA
            p[keyPath: kp].byProject[entry.project, default: ProjectStats()].main.linesRemoved += mainLR
            p[keyPath: kp].byProject[entry.project, default: ProjectStats()].subagents.cost += subagentTotal.cost
            p[keyPath: kp].byProject[entry.project, default: ProjectStats()].subagents.linesAdded += subagentTotal.linesAdded
            p[keyPath: kp].byProject[entry.project, default: ProjectStats()].subagents.linesRemoved += subagentTotal.linesRemoved
        }
    }

    /// Compute per-model cost/lines from transition history.
    /// - `absoluteCost`: the raw cumulative .dat value (always absolute)
    /// - `periodCost`: the entry's period cost (may be incremental after midnight dedup)
    /// History entries record absolute cumulative costs at each model switch.
    private func modelBreakdown(
        history: [(cost: Double, la: Int, lr: Int, model: String)],
        absoluteCost: Double, periodCost: Double,
        totalLA: Int, totalLR: Int
    ) -> [String: SourceModelStats] {
        var rawByModel: [String: SourceModelStats] = [:]
        let baseLA = history[0].la
        let baseLR = history[0].lr

        for i in 0..<history.count {
            let current = history[i]
            let nextCost = (i + 1 < history.count) ? history[i + 1].cost : absoluteCost
            let nextLA   = (i + 1 < history.count) ? history[i + 1].la   : baseLA + totalLA
            let nextLR   = (i + 1 < history.count) ? history[i + 1].lr   : baseLR + totalLR
            let dc  = max(0, nextCost - current.cost)
            let dla = max(0, nextLA - current.la)
            let dlr = max(0, nextLR - current.lr)
            rawByModel[current.model, default: SourceModelStats()].cost += dc
            rawByModel[current.model, default: SourceModelStats()].linesAdded += dla
            rawByModel[current.model, default: SourceModelStats()].linesRemoved += dlr
        }

        // For same-day sessions (no midnight dedup), the cost before .models tracking
        // started is untracked. Attribute it to the first model in the history.
        // Midnight-spanning sessions (periodCost < absoluteCost): the pre-tracking
        // cost represents yesterday's usage — don't re-attribute it; scale will correct.
        let isSameDay = abs(periodCost - absoluteCost) < 0.001
        let rawTotal = rawByModel.values.reduce(0.0) { $0 + $1.cost }
        if isSameDay {
            let untrackedCost = absoluteCost - rawTotal
            if untrackedCost > 0.001 {
                rawByModel[history[0].model, default: SourceModelStats()].cost += untrackedCost
            }
            // No scaling needed — all cost is now accounted for
            return rawByModel
        }

        // Midnight-spanning: scale proportionally to the incremental periodCost
        guard rawTotal > 0 else { return rawByModel }
        let scale = periodCost / rawTotal
        var result: [String: SourceModelStats] = [:]
        for (model, stats) in rawByModel {
            result[model] = SourceModelStats(
                cost: stats.cost * scale,
                linesAdded: stats.linesAdded,
                linesRemoved: stats.linesRemoved
            )
        }
        return result
    }

    private func collectEntries(
        under root: URL, source: AgentSource, since monthStart: Date,
        into entries: inout [DatEntry],
        histories: inout [String: [(cost: Double, la: Int, lr: Int, model: String)]],
        subagents: inout [String: [String: SourceModelStats]]
    ) {
        let fm = FileManager.default
        let calendar = Calendar.current
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        guard let dateDirs = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else { return }

        for dateDir in dateDirs {
            let dirName = dateDir.lastPathComponent
            guard let dirDate = dateFmt.date(from: dirName) else { continue }
            let dirDay = calendar.startOfDay(for: dirDate)

            guard dirDay >= monthStart else { continue }

            guard let files = try? fm.contentsOfDirectory(
                at: dateDir, includingPropertiesForKeys: nil
            ) else { continue }

            // Build PID → project name map from .project files in this date folder
            var pidToProject: [String: String] = [:]
            for file in files where file.pathExtension == "project" {
                guard let raw = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let pid = file.deletingPathExtension().lastPathComponent
                let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                pidToProject[pid] = (path as NSString).lastPathComponent
            }

            // Build PID → sessionID map from .agent.json files
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

                entries.append(DatEntry(
                    pid: pid, day: dirDay, cost: cost, absoluteCost: cost,
                    linesAdded: la, linesRemoved: lr,
                    model: model, source: source,
                    project: pidToProject[pid] ?? "",
                    sessionID: pidToSession[pid] ?? ""
                ))

                // Read .models file for per-model breakdown
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
                        histories["\(pid)\t\(source.rawValue)"] = transitions
                    }
                }

                // Read {pid}.subagents.json for subagent per-model cost
                let subagentsFile = dateDir.appendingPathComponent("\(pid).subagents.json")
                if let subData = try? Data(contentsOf: subagentsFile),
                   let subMap = try? JSONDecoder().decode([String: SourceModelStats].self, from: subData),
                   !subMap.isEmpty {
                    subagents["\(pid)\t\(source.rawValue)"] = subMap
                }
            }
        }
    }
}
