import Foundation

/**
 solid-name: StatsFileAggregating
 solid-category: abstraction
 solid-description: Contract that aggregates files into a statistics map.
 */
protocol StatsFileAggregating {
    func aggregate(files: Set<URL>) -> [String: SessionStats]
}

/**
 solid-name: StatsFileAggregator
 solid-category: service
 solid-description: Aggregates files into a statistics map.
 */
struct StatsFileAggregator: StatsFileAggregating {
    private let parser: LogMessageParsing
    private let fileSystem: FileSystemProviding
    private let cache: StatsFileCache
    private let dayFormatter: DayFormatting

    init(
        parser: LogMessageParsing = LogParser(),
        fileSystem: FileSystemProviding = FileManager.default,
        cache: StatsFileCache = StatsFileCache(),
        dayFormatter: DayFormatting = DayFormatter()
    ) {
        self.parser = parser
        self.fileSystem = fileSystem
        self.cache = cache
        self.dayFormatter = dayFormatter
    }

    func aggregate(files: Set<URL>) -> [String: SessionStats] {
        var combined: [String: SessionStats] = [:]
        for url in files {
            for (dayKey, stats) in statsByDay(for: url) {
                combined[dayKey, default: SessionStats()].merge(stats)
            }
        }
        return combined
    }

    private func statsByDay(for url: URL) -> [String: SessionStats] {
        let mtime = modificationDate(of: url)
        return cache.statsByDay(for: url, mtime: mtime) {
            let messages = parser.parseMessages(at: url)
            let fallbackDay = dayFormatter.dayString(from: mtime ?? Date())
            return SessionStatsAggregator(messages: messages).aggregateByDay(fallbackDay: fallbackDay)
        }
    }

    private func modificationDate(of url: URL) -> Date? {
        let attrs = try? fileSystem.attributesOfItem(atPath: url.path)
        return attrs?[.modificationDate] as? Date
    }
}