import Foundation

/// Rate limit event extracted from JSONL session logs.
public struct RateLimitEvent: Sendable {
    public let timestamp: Date
    public let message: String   // e.g. "You've hit your limit · resets 3pm (America/Toronto)"
    public let sessionID: String
    public let resetsAt: Double?  // Unix epoch from live agent data, if available
}

/// Scan an account's JSONL files for rate limit events.
public enum RateLimitScanner {
    /// Cache: claudeDir → (scanTime, event). Re-scan at most every 30 seconds.
    private static var cache: [String: (scannedAt: Date, event: RateLimitEvent?)] = [:]

    /// Find the most recent rate limit event across all sessions in an account.
    public static func lastRateLimitEvent(claudeDir: String) -> RateLimitEvent? {
        let now = Date()
        if let cached = cache[claudeDir], now.timeIntervalSince(cached.scannedAt) < 30 {
            return cached.event
        }
        let event = scanForRateLimitEvent(claudeDir: claudeDir)
        cache[claudeDir] = (scannedAt: now, event: event)
        return event
    }

    private static func scanForRateLimitEvent(claudeDir: String) -> RateLimitEvent? {
        let projectsDir = URL(fileURLWithPath: claudeDir).appendingPathComponent("projects")
        let fm = FileManager.default
        guard let projectDirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return nil }

        var latest: RateLimitEvent?
        let now = Date()
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for projectDir in projectDirs {
            guard let files = try? fm.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                // Only check files modified in last 24h
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let mtime = attrs.contentModificationDate,
                      now.timeIntervalSince(mtime) < 86400
                else { continue }

                guard let data = try? Data(contentsOf: file),
                      let content = String(data: data, encoding: .utf8)
                else { continue }

                let sessionID = file.deletingPathExtension().lastPathComponent

                // Scan from end (most recent entries last) for rate_limit errors
                let lines = content.split(separator: "\n")
                for line in lines.reversed() {
                    guard line.contains("\"rate_limit\"") else { continue }
                    guard let lineData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          json["error"] as? String == "rate_limit"
                    else { continue }

                    let ts = (json["timestamp"] as? String).flatMap { isoFmt.date(from: $0) } ?? now
                    var text = ""
                    if let msg = json["message"] as? [String: Any] {
                        // message.content is at the top level of the message object
                        if let contentArr = msg["content"] as? [[String: Any]] {
                            text = contentArr.compactMap { $0["text"] as? String }.joined(separator: " ")
                        }
                    }

                    let parsedReset = parseResetTime(from: text, relativeTo: ts)
                    let event = RateLimitEvent(timestamp: ts, message: text, sessionID: sessionID, resetsAt: parsedReset)
                    if latest == nil || ts > latest!.timestamp {
                        latest = event
                    }
                    break // Only need the latest from this file
                }
            }
        }
        return latest
    }

    /// Parse "resets 3pm (America/Toronto)" → Unix timestamp.
    private static func parseResetTime(from message: String, relativeTo eventDate: Date) -> Double? {
        guard let range = message.range(of: "resets ", options: .caseInsensitive) else { return nil }
        let after = String(message[range.upperBound...])

        // Extract timezone from parentheses
        var tzID: String?
        if let openParen = after.firstIndex(of: "("),
           let closeParen = after.firstIndex(of: ")") {
            tzID = String(after[after.index(after: openParen)..<closeParen])
        }
        let tz = tzID.flatMap { TimeZone(identifier: $0) } ?? .current

        // Extract time string before the parenthesis
        let timeStr = (after.firstIndex(of: "(").map { String(after[..<$0]) } ?? after)
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        // Parse hour/minute from "3pm", "3:30pm", "15:00"
        let fmt = DateFormatter()
        fmt.timeZone = tz
        fmt.locale = Locale(identifier: "en_US_POSIX")

        var parsedHour: Int?
        var parsedMinute: Int = 0
        for format in ["h:mma", "ha", "HH:mm", "H:mm"] {
            fmt.dateFormat = format
            if let parsed = fmt.date(from: timeStr) {
                let comps = Calendar.current.dateComponents(in: tz, from: parsed)
                parsedHour = comps.hour
                parsedMinute = comps.minute ?? 0
                break
            }
        }
        guard let hour = parsedHour else { return nil }

        // Build the reset date: event's date + parsed time in the correct timezone
        var cal = Calendar.current
        cal.timeZone = tz
        let eventDay = cal.dateComponents([.year, .month, .day], from: eventDate)
        var resetComps = DateComponents()
        resetComps.year = eventDay.year
        resetComps.month = eventDay.month
        resetComps.day = eventDay.day
        resetComps.hour = hour
        resetComps.minute = parsedMinute
        resetComps.timeZone = tz

        guard let resetDate = cal.date(from: resetComps) else { return nil }

        // If reset time is before the event, it must be the next day
        let finalDate = resetDate < eventDate
            ? cal.date(byAdding: .day, value: 1, to: resetDate) ?? resetDate
            : resetDate
        return finalDate.timeIntervalSince1970
    }
}

/// Parsed data from ~/.claude/stats-cache.json — Claude's built-in usage stats.
/// This is the authoritative source for token usage on Pro/Max plans.
public struct StatsCache: Sendable {
    public struct DailyActivity: Sendable {
        public let date: String
        public let messageCount: Int
        public let sessionCount: Int
        public let toolCallCount: Int
    }

    public struct DailyModelTokens: Sendable {
        public let date: String
        public let tokensByModel: [String: Int]  // model ID → output tokens
    }

    public struct ModelUsage: Sendable {
        public let modelID: String
        public let inputTokens: Int
        public let outputTokens: Int
        public let cacheReadInputTokens: Int
        public let cacheCreationInputTokens: Int
    }

    public let dailyActivity: [DailyActivity]
    public let dailyModelTokens: [DailyModelTokens]
    public let modelUsage: [ModelUsage]
    public let totalSessions: Int
    public let totalMessages: Int

    /// Total output tokens across all models (primary rate-limit metric).
    public var totalOutputTokens: Int {
        modelUsage.reduce(0) { $0 + $1.outputTokens }
    }

    /// Total input tokens (including cache) across all models.
    public var totalInputTokens: Int {
        modelUsage.reduce(0) { $0 + $1.inputTokens + $1.cacheReadInputTokens + $1.cacheCreationInputTokens }
    }

    /// Daily output tokens for the current month.
    public func monthlyDailyTokens(calendar: Calendar = .current, now: Date = Date()) -> [Int: Int] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let monthStartStr = fmt.string(from: monthStart)

        var result: [Int: Int] = [:]  // dayOfMonth → total output tokens
        for entry in dailyModelTokens where entry.date >= monthStartStr {
            if let date = fmt.date(from: entry.date) {
                let day = calendar.component(.day, from: date)
                let totalTokens = entry.tokensByModel.values.reduce(0, +)
                result[day, default: 0] += totalTokens
            }
        }
        return result
    }

    /// Average daily messages this month.
    public func monthlyAvgMessages(calendar: Calendar = .current, now: Date = Date()) -> Double {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let monthStartStr = fmt.string(from: monthStart)

        let monthActivity = dailyActivity.filter { $0.date >= monthStartStr }
        guard !monthActivity.isEmpty else { return 0 }
        let total = monthActivity.reduce(0) { $0 + $1.messageCount }
        return Double(total) / Double(monthActivity.count)
    }

    /// Cache: claudeDir → (loadTime, stats). Re-read at most every 30 seconds.
    private static var cache: [String: (loadedAt: Date, stats: StatsCache?)] = [:]

    /// Parse from a .claude directory. Cached for 30 seconds.
    public static func load(claudeDir: String) -> StatsCache? {
        let now = Date()
        if let cached = cache[claudeDir], now.timeIntervalSince(cached.loadedAt) < 30 {
            return cached.stats
        }
        let stats = loadFromDisk(claudeDir: claudeDir)
        cache[claudeDir] = (loadedAt: now, stats: stats)
        return stats
    }

    private static func loadFromDisk(claudeDir: String) -> StatsCache? {
        let url = URL(fileURLWithPath: claudeDir).appendingPathComponent("stats-cache.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let activity = (json["dailyActivity"] as? [[String: Any]] ?? []).compactMap { entry -> DailyActivity? in
            guard let date = entry["date"] as? String else { return nil }
            return DailyActivity(
                date: date,
                messageCount: entry["messageCount"] as? Int ?? 0,
                sessionCount: entry["sessionCount"] as? Int ?? 0,
                toolCallCount: entry["toolCallCount"] as? Int ?? 0
            )
        }

        let dailyTokens = (json["dailyModelTokens"] as? [[String: Any]] ?? []).compactMap { entry -> DailyModelTokens? in
            guard let date = entry["date"] as? String,
                  let tokens = entry["tokensByModel"] as? [String: Int] else { return nil }
            return DailyModelTokens(date: date, tokensByModel: tokens)
        }

        let modelUsageDict = json["modelUsage"] as? [String: [String: Any]] ?? [:]
        let modelUsages = modelUsageDict.map { (modelID, info) -> ModelUsage in
            ModelUsage(
                modelID: modelID,
                inputTokens: info["inputTokens"] as? Int ?? 0,
                outputTokens: info["outputTokens"] as? Int ?? 0,
                cacheReadInputTokens: info["cacheReadInputTokens"] as? Int ?? 0,
                cacheCreationInputTokens: info["cacheCreationInputTokens"] as? Int ?? 0
            )
        }

        return StatsCache(
            dailyActivity: activity,
            dailyModelTokens: dailyTokens,
            modelUsage: modelUsages,
            totalSessions: json["totalSessions"] as? Int ?? 0,
            totalMessages: json["totalMessages"] as? Int ?? 0
        )
    }
}
