import Foundation

struct PeriodStats {
    var cost: Double = 0
    var linesAdded: Int = 0
    var linesRemoved: Int = 0
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

    func reload() {
        let fm = FileManager.default
        let calendar = Calendar.current
        let now = Date()

        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: now)
        // weekday: 1=Sun..7=Sat -> shift to Mon-based
        let daysSinceMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        var d = PeriodStats()
        var w = PeriodStats()
        var m = PeriodStats()

        // .dat files are written by the statusline (terminal sessions) and by
        // AgentTracker (Commander sessions), so all sessions are covered here.
        guard let dateDirs = try? fm.contentsOfDirectory(
            at: usageDir, includingPropertiesForKeys: nil
        ) else {
            day = d; week = w; month = m
            return
        }

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

                let cost = Double(parts.first ?? "0") ?? 0
                let la = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
                let lr = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0

                m.cost += cost; m.linesAdded += la; m.linesRemoved += lr

                if dirDay >= weekStart {
                    w.cost += cost; w.linesAdded += la; w.linesRemoved += lr
                }
                if dirDay == today {
                    d.cost += cost; d.linesAdded += la; d.linesRemoved += lr
                }
            }
        }

        day = d; week = w; month = m
    }
}
