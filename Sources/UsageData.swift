import Foundation

struct SourceModelStats {
    var cost: Double = 0
    var linesAdded: Int = 0
    var linesRemoved: Int = 0
}

struct SourceStats {
    var total = SourceModelStats()
    var byModel: [String: SourceModelStats] = [:]
}

struct PeriodStats {
    var cost: Double = 0
    var linesAdded: Int = 0
    var linesRemoved: Int = 0
    var cli = SourceStats()
    var commander = SourceStats()
}

@Observable
final class UsageData {
    var day = PeriodStats()
    var week = PeriodStats()
    var month = PeriodStats()

    private let usageDir: URL

    init() {
        usageDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/usage")
        reload()
    }

    /// A single .dat entry with its metadata.
    private struct DatEntry {
        let pid: String
        let day: Date       // start of day for the folder
        let cost: Double
        let linesAdded: Int
        let linesRemoved: Int
        let model: String
        let source: AgentSource
    }

    func reload() {
        let calendar = Calendar.current
        let now = Date()

        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        // Collect all .dat entries from both sources
        var entries: [DatEntry] = []
        collectEntries(under: usageDir, source: .cli, since: monthStart, into: &entries)
        collectEntries(under: CommanderSupport.baseDir, source: .commander, since: monthStart, into: &entries)

        // Deduplicate: .dat stores cumulative session cost, so a PID spanning multiple days
        // has entries in each day's folder. Keep only the latest day per PID — that has the
        // most up-to-date cumulative cost.
        // For "today" specifically, subtract the previous day's value to get incremental cost.
        var latestByPID: [String: DatEntry] = [:]     // PID → latest entry
        var previousByPID: [String: DatEntry] = [:]   // PID → second-latest entry

        for entry in entries.sorted(by: { $0.day < $1.day }) {
            if let existing = latestByPID[entry.pid] {
                previousByPID[entry.pid] = existing
            }
            latestByPID[entry.pid] = entry
        }

        var d = PeriodStats()
        var w = PeriodStats()
        var m = PeriodStats()

        for (pid, latest) in latestByPID {
            let prev = previousByPID[pid]

            // Month: use latest cumulative value (no double-count)
            accumulate(latest, into: &m)

            // Week: use latest if within this week
            if latest.day >= weekStart {
                // If previous entry is also in this week, use incremental (latest - previous)
                if let prev, prev.day >= weekStart {
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
            linesAdded: max(0, latest.linesAdded - previous.linesAdded),
            linesRemoved: max(0, latest.linesRemoved - previous.linesRemoved),
            model: latest.model,
            source: latest.source
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

        if !entry.model.isEmpty {
            p[keyPath: kp].byModel[entry.model, default: SourceModelStats()].cost += entry.cost
            p[keyPath: kp].byModel[entry.model, default: SourceModelStats()].linesAdded += entry.linesAdded
            p[keyPath: kp].byModel[entry.model, default: SourceModelStats()].linesRemoved += entry.linesRemoved
        }
    }

    private func collectEntries(
        under root: URL, source: AgentSource, since monthStart: Date,
        into entries: inout [DatEntry]
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
                    pid: pid, day: dirDay, cost: cost,
                    linesAdded: la, linesRemoved: lr,
                    model: model, source: source
                ))
            }
        }
    }
}
