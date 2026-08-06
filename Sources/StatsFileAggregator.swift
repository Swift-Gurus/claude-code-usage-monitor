import Foundation

/**
 solid-name: StatsFileAggregating
 solid-category: abstraction
 solid-description: Contract that aggregates files into a statistics map.
 */
protocol StatsFileAggregating: Sendable {
    func aggregate(files: Set<StatsSessionFile>) async -> [String: SessionStats]
}

/**
 solid-name: StatsFileAggregator
 solid-category: service
 solid-description: Aggregates files into a statistics map.
 */
actor StatsFileAggregator: StatsFileAggregating {
    private let claudeParser: LogMessageParsing
    private let codexParser: LogMessageParsing
    private let fileSystem: FileSystemProviding
    private let cache: StatsFileCache
    private let dayFormatter: DayFormatting

    init(
        claudeParser: LogMessageParsing = LogParser(),
        codexParser: LogMessageParsing = CodexLogParser(includeTokenUsageMessages: true),
        fileSystem: FileSystemProviding = FileManager.default,
        cache: StatsFileCache = StatsFileCache(),
        dayFormatter: DayFormatting = DayFormatter()
    ) {
        self.claudeParser = claudeParser
        self.codexParser = codexParser
        self.fileSystem = fileSystem
        self.cache = cache
        self.dayFormatter = dayFormatter
    }

    func aggregate(files: Set<StatsSessionFile>) async -> [String: SessionStats] {
        var combined: [String: SessionStats] = [:]
        for file in files {
            for (dayKey, stats) in statsByDay(for: file) {
                combined[dayKey, default: SessionStats()].merge(stats)
            }
        }
        return combined
    }

    private func statsByDay(for file: StatsSessionFile) -> [String: SessionStats] {
        let mtime = modificationDate(of: file.url)
        return cache.statsByDay(for: file.url, mtime: mtime) {
            let messages = parser(for: file.format).parseMessages(at: file.url)
            let fallbackDay = dayFormatter.dayString(from: mtime ?? Date())
            return SessionStatsAggregator(messages: messages).aggregateByDay(fallbackDay: fallbackDay)
        }
    }

    private func parser(for format: StatsSessionFile.Format) -> LogMessageParsing {
        switch format {
        case .claude: return claudeParser
        case .codex: return codexParser
        }
    }

    private func modificationDate(of url: URL) -> Date? {
        let attrs = try? fileSystem.attributesOfItem(atPath: url.path)
        return attrs?[.modificationDate] as? Date
    }
}
