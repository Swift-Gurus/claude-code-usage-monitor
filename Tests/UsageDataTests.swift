import Foundation
import Testing
@testable import ClaudeUsageBarLib

@Suite("UsageData")
struct UsageDataTests {

    /// Create a temp usage directory with .dat and .models files, then test UsageData reload.
    private func withTempUsageDir(_ block: (URL) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageBarTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try block(tmp)
    }

    private func todayStr() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func writeDat(dir: URL, pid: String, cost: Double, la: Int, lr: Int, model: String) throws {
        try "\(cost) \(la) \(lr) \(model)".write(to: dir.appendingPathComponent("\(pid).dat"), atomically: true, encoding: .utf8)
    }

    private func writeModels(dir: URL, pid: String, transitions: [(Double, Int, Int, String)]) throws {
        let lines = transitions.map { "\($0.0)\t\($0.1)\t\($0.2)\t\($0.3)" }.joined(separator: "\n")
        try lines.write(to: dir.appendingPathComponent("\(pid).models"), atomically: true, encoding: .utf8)
    }

    // MARK: - Model Breakdown

    @Test("Single model — all cost attributed to one model")
    func singleModel() throws {
        try withTempUsageDir { root in
            let today = todayStr()
            let dayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)
            try writeDat(dir: dayDir, pid: "1234", cost: 50.0, la: 100, lr: 50, model: "Opus 4.6")

            let data = UsageData(testUsageDir: root)
            #expect(data.day.cost == 50.0)
            #expect(data.day.cli.byModel["Opus 4.6"]?.cost == 50.0)
            #expect(data.day.cli.byModel.count == 1)
        }
    }

    @Test("Multi-model transitions split cost correctly")
    func multiModelBreakdown() throws {
        try withTempUsageDir { root in
            let today = todayStr()
            let dayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)

            // Session: started Opus at $0, switched to Sonnet at $45, back to Opus at $50, total $55
            try writeDat(dir: dayDir, pid: "1234", cost: 55.0, la: 200, lr: 100, model: "Opus 4.6")
            try writeModels(dir: dayDir, pid: "1234", transitions: [
                (0, 0, 0, "Opus 4.6"),
                (45, 150, 70, "Sonnet 4.6"),
                (50, 180, 90, "Opus 4.6"),
            ])

            let data = UsageData(testUsageDir: root)
            let opus = data.day.cli.byModel["Opus 4.6"]
            let sonnet = data.day.cli.byModel["Sonnet 4.6"]

            #expect(data.day.cost == 55.0)
            // Opus: (45-0) + (55-50) = 50, Sonnet: (50-45) = 5
            // Scaled to match total: raw sum = 50+5 = 55, scale = 55/55 = 1.0
            #expect(opus != nil)
            #expect(sonnet != nil)
            #expect(abs((opus?.cost ?? 0) - 50.0) < 0.01)
            #expect(abs((sonnet?.cost ?? 0) - 5.0) < 0.01)
        }
    }

    @Test("Model breakdown with two models equal split")
    func equalSplit() throws {
        try withTempUsageDir { root in
            let today = todayStr()
            let dayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)

            try writeDat(dir: dayDir, pid: "5678", cost: 100.0, la: 0, lr: 0, model: "Sonnet 4.6")
            try writeModels(dir: dayDir, pid: "5678", transitions: [
                (0, 0, 0, "Opus 4.6"),
                (50, 0, 0, "Sonnet 4.6"),
            ])

            let data = UsageData(testUsageDir: root)
            let opus = data.day.cli.byModel["Opus 4.6"]
            let sonnet = data.day.cli.byModel["Sonnet 4.6"]
            #expect(abs((opus?.cost ?? 0) - 50.0) < 0.01)
            #expect(abs((sonnet?.cost ?? 0) - 50.0) < 0.01)
        }
    }

    @Test("Single entry in .models — no breakdown, falls back to .dat model")
    func singleModelEntry() throws {
        try withTempUsageDir { root in
            let today = todayStr()
            let dayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)

            try writeDat(dir: dayDir, pid: "9999", cost: 30.0, la: 10, lr: 5, model: "Haiku 4.5")
            try writeModels(dir: dayDir, pid: "9999", transitions: [
                (0, 0, 0, "Haiku 4.5"),
            ])

            let data = UsageData(testUsageDir: root)
            #expect(data.day.cli.byModel["Haiku 4.5"]?.cost == 30.0)
            #expect(data.day.cli.byModel.count == 1)
        }
    }

    // MARK: - Multiple Sessions

    @Test("Multiple PIDs aggregate independently")
    func multiplePIDs() throws {
        try withTempUsageDir { root in
            let today = todayStr()
            let dayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)

            try writeDat(dir: dayDir, pid: "1111", cost: 20.0, la: 50, lr: 10, model: "Opus 4.6")
            try writeDat(dir: dayDir, pid: "2222", cost: 30.0, la: 80, lr: 20, model: "Sonnet 4.6")

            let data = UsageData(testUsageDir: root)
            #expect(data.day.cost == 50.0)
            #expect(data.day.linesAdded == 130)
            #expect(data.day.linesRemoved == 30)
            #expect(data.day.cli.byModel["Opus 4.6"]?.cost == 20.0)
            #expect(data.day.cli.byModel["Sonnet 4.6"]?.cost == 30.0)
        }
    }

    // MARK: - Dedup Across Days

    @Test("Multi-day session uses incremental cost for today")
    func multiDayIncremental() throws {
        try withTempUsageDir { root in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let today = fmt.string(from: Date())
            let yesterday = fmt.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)

            let yesterdayDir = root.appendingPathComponent(yesterday)
            let todayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: yesterdayDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: todayDir, withIntermediateDirectories: true)

            // Same PID, cumulative cost grows across days
            try writeDat(dir: yesterdayDir, pid: "1234", cost: 40.0, la: 100, lr: 50, model: "Opus 4.6")
            try writeDat(dir: todayDir, pid: "1234", cost: 55.0, la: 150, lr: 70, model: "Opus 4.6")

            let data = UsageData(testUsageDir: root)

            // Today: incremental = 55 - 40 = 15
            #expect(abs(data.day.cost - 15.0) < 0.01)
            #expect(data.day.linesAdded == 50)  // 150 - 100
            #expect(data.day.linesRemoved == 20) // 70 - 50

            // Month: uses latest cumulative = 55
            #expect(abs(data.month.cost - 55.0) < 0.01)
        }
    }

    @Test("Single-day session — today equals cumulative")
    func singleDayNoDedup() throws {
        try withTempUsageDir { root in
            let today = todayStr()
            let dayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)
            try writeDat(dir: dayDir, pid: "5555", cost: 25.0, la: 30, lr: 10, model: "Haiku 4.5")

            let data = UsageData(testUsageDir: root)
            #expect(abs(data.day.cost - 25.0) < 0.01)
            #expect(abs(data.month.cost - 25.0) < 0.01)
        }
    }

    // MARK: - Week Boundaries

    @Test("Week aggregation excludes entries from before this week")
    func weekBoundary() throws {
        try withTempUsageDir { root in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let calendar = Calendar.current

            // Create an entry from 2 weeks ago (different PID so no dedup interaction)
            // This may or may not be in the current month depending on date
            let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date())!
            let oldDir = root.appendingPathComponent(fmt.string(from: twoWeeksAgo))
            try FileManager.default.createDirectory(at: oldDir, withIntermediateDirectories: true)
            try writeDat(dir: oldDir, pid: "old", cost: 100.0, la: 500, lr: 200, model: "Opus 4.6")

            // Create an entry from today
            let today = todayStr()
            let todayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: todayDir, withIntermediateDirectories: true)
            try writeDat(dir: todayDir, pid: "new", cost: 10.0, la: 20, lr: 5, model: "Sonnet 4.6")

            let data = UsageData(testUsageDir: root)

            // Week should only include today's PID (2 weeks ago is always outside current week)
            #expect(abs(data.week.cost - 10.0) < 0.01)
            // Month includes both only if 2 weeks ago is in the same month
            #expect(data.month.cost >= 10.0)
        }
    }

    @Test("Multi-day session with model switch today splits incremental cost correctly")
    func multiDayModelSwitch() throws {
        try withTempUsageDir { root in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let today = fmt.string(from: Date())
            let yesterday = fmt.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)

            let yesterdayDir = root.appendingPathComponent(yesterday)
            let todayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: yesterdayDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: todayDir, withIntermediateDirectories: true)

            // Yesterday: session at $40 on Opus
            try writeDat(dir: yesterdayDir, pid: "1234", cost: 40.0, la: 100, lr: 50, model: "Opus 4.6")

            // Today: session at $60 total, switched Opus→Sonnet at $50
            try writeDat(dir: todayDir, pid: "1234", cost: 60.0, la: 200, lr: 80, model: "Sonnet 4.6")
            try writeModels(dir: todayDir, pid: "1234", transitions: [
                (40, 100, 50, "Opus 4.6"),     // cost at start of today
                (50, 160, 70, "Sonnet 4.6"),   // switched at $50
            ])

            let data = UsageData(testUsageDir: root)

            // Today's incremental: 60 - 40 = $20
            #expect(abs(data.day.cost - 20.0) < 0.01)

            // Model breakdown for today:
            // Raw: Opus = 50-40 = $10, Sonnet = 60-50 = $10
            // Raw total = $20, scale = 20/20 = 1.0
            let opus = data.day.cli.byModel["Opus 4.6"]
            let sonnet = data.day.cli.byModel["Sonnet 4.6"]
            #expect(opus != nil)
            #expect(sonnet != nil)
            #expect(abs((opus?.cost ?? 0) - 10.0) < 0.01)
            #expect(abs((sonnet?.cost ?? 0) - 10.0) < 0.01)
        }
    }

    @Test(".models started mid-session — untracked initial cost attributed to first model")
    func modelsStartedMidSession() throws {
        try withTempUsageDir { root in
            let today = todayStr()
            let dayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)

            // Session total: $46.12. .models started at $39.87 (Opus was already running).
            // Sonnet first appeared at $39.87. The $39.87 of pre-tracking Opus cost
            // should be attributed to Opus (first model in .models).
            try writeDat(dir: dayDir, pid: "53590", cost: 46.12, la: 1605, lr: 421, model: "Sonnet 4.6")
            try writeModels(dir: dayDir, pid: "53590", transitions: [
                (39.87, 1603, 419, "Opus 4.6"),
                (39.87, 1603, 419, "Sonnet 4.6"), // switch happened at same cost
                (43.12, 1603, 419, "Sonnet 4.6"),
                (46.12, 1605, 421, "Sonnet 4.6"),
            ])

            let data = UsageData(testUsageDir: root)

            let opus = data.day.cli.byModel["Opus 4.6"]?.cost ?? 0
            let sonnet = data.day.cli.byModel["Sonnet 4.6"]?.cost ?? 0

            // Opus should get the untracked $39.87 (pre-tracking cost)
            // Sonnet gets the tracked portion: 46.12 - 39.87 = $6.25
            #expect(abs(opus - 39.87) < 0.01, "Opus should get pre-tracking cost")
            #expect(abs(sonnet - 6.25) < 0.01, "Sonnet should get only tracked cost")
            #expect(abs(opus + sonnet - 46.12) < 0.01, "Total should equal .dat cost")
        }
    }

    @Test("Three model switches in one session")
    func threeModelSwitches() throws {
        try withTempUsageDir { root in
            let today = todayStr()
            let dayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)

            // Opus→Sonnet→Haiku→Opus, total $100
            try writeDat(dir: dayDir, pid: "7777", cost: 100.0, la: 0, lr: 0, model: "Opus 4.6")
            try writeModels(dir: dayDir, pid: "7777", transitions: [
                (0, 0, 0, "Opus 4.6"),
                (30, 0, 0, "Sonnet 4.6"),
                (50, 0, 0, "Haiku 4.5"),
                (60, 0, 0, "Opus 4.6"),
            ])

            let data = UsageData(testUsageDir: root)

            // Opus: (30-0) + (100-60) = 70, Sonnet: (50-30) = 20, Haiku: (60-50) = 10
            let opus = data.day.cli.byModel["Opus 4.6"]?.cost ?? 0
            let sonnet = data.day.cli.byModel["Sonnet 4.6"]?.cost ?? 0
            let haiku = data.day.cli.byModel["Haiku 4.5"]?.cost ?? 0

            #expect(abs(opus - 70.0) < 0.01)
            #expect(abs(sonnet - 20.0) < 0.01)
            #expect(abs(haiku - 10.0) < 0.01)
            #expect(abs(opus + sonnet + haiku - 100.0) < 0.01)
        }
    }

    // MARK: - Empty Directory

    @Test("Empty directory produces zero stats")
    func emptyDir() throws {
        try withTempUsageDir { root in
            let data = UsageData(testUsageDir: root)
            #expect(data.day.cost == 0)
            #expect(data.week.cost == 0)
            #expect(data.month.cost == 0)
        }
    }

    @Test("Missing .dat files ignored gracefully")
    func missingDat() throws {
        try withTempUsageDir { root in
            let today = todayStr()
            let dayDir = root.appendingPathComponent(today)
            try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)
            // Write only .models, no .dat
            try writeModels(dir: dayDir, pid: "9999", transitions: [
                (0, 0, 0, "Opus 4.6"),
                (10, 5, 2, "Sonnet 4.6"),
            ])

            let data = UsageData(testUsageDir: root)
            #expect(data.day.cost == 0)
        }
    }
}

