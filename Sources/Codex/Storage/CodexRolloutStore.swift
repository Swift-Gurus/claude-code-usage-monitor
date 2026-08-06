import Foundation

protocol CodexRolloutReading {
    func indexedSessionTitles() -> [String: String]
    func rolloutURLs(modifiedSince date: Date) -> [URL]
    func rolloutURL(threadID: String) -> URL?
    func rolloutEvents(threadID: String, limit: Int) -> [CodexRolloutEvent]
    func parsedRollout(threadID: String, fallbackTitle: String) -> CodexParsedRollout?
    func recentParsedRollouts(now: Date, threshold: TimeInterval, titlesByID: [String: String]) -> [String: CodexParsedRollout]
}

struct CodexRolloutStore: CodexRolloutReading {
    private let paths: CodexPaths
    private let fileManager: FileManager
    private let decoder: CodexJSONLDecoding
    private let dateParser: CodexDateParser

    init(
        paths: CodexPaths,
        fileManager: FileManager = .default,
        decoder: CodexJSONLDecoding = CodexJSONLFileDecoder(),
        dateParser: CodexDateParser = CodexDateParser()
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.decoder = decoder
        self.dateParser = dateParser
    }

    func indexedSessionTitles() -> [String: String] {
        var result: [String: String] = [:]
        for row in decoder.decodeLines(at: paths.sessionIndexURL, as: CodexSessionIndexRow.self) where !row.id.isEmpty {
            result[row.id] = row.threadName ?? ""
        }
        return result
    }

    func rolloutURLs(modifiedSince date: Date) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: paths.sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if modifiedAt >= date {
                urls.append(url)
            }
        }
        return urls
    }

    func rolloutURL(threadID: String) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: paths.sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var bestMatch: (url: URL, modifiedAt: Date)?
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl", threadIDFromRolloutURL(url) == threadID else { continue }
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if bestMatch == nil || modifiedAt > bestMatch!.modifiedAt {
                bestMatch = (url, modifiedAt)
            }
        }

        return bestMatch?.url
    }

    func rolloutEvents(threadID: String, limit: Int) -> [CodexRolloutEvent] {
        guard let url = rolloutURL(threadID: threadID) else { return [] }

        let events = decoder.decodeLines(at: url, as: CodexRolloutLine.self).compactMap { line in
            makeRolloutEvent(from: line)
        }
        return Array(events.suffix(limit)).reversed()
    }

    func parsedRollout(threadID: String, fallbackTitle: String) -> CodexParsedRollout? {
        guard let url = rolloutURL(threadID: threadID) else { return nil }
        return parseRollout(at: url, fallbackTitle: fallbackTitle)
    }

    func recentParsedRollouts(now: Date, threshold: TimeInterval, titlesByID: [String: String]) -> [String: CodexParsedRollout] {
        var rollouts: [String: CodexParsedRollout] = [:]
        for url in rolloutURLs(modifiedSince: now.addingTimeInterval(-threshold)) {
            let threadID = threadIDFromRolloutURL(url)
            if let parsed = parseRollout(at: url, fallbackTitle: titlesByID[threadID] ?? "") {
                rollouts[threadID] = parsed
            }
        }
        return rollouts
    }

    private func parseRollout(at url: URL, fallbackTitle: String) -> CodexParsedRollout? {
        let threadID = threadIDFromRolloutURL(url)
        var title = fallbackTitle
        var cwd = ""
        var model = ""
        var updatedAt = Date.distantPast
        var startedAt = Date.distantPast
        var totalTokens = 0
        var currentContextTokens = 0
        var contextWindow = 0
        var rateLimits: RateLimits?

        for line in decoder.decodeLines(at: url, as: CodexRolloutLine.self) {
            if let timestamp = line.timestamp.flatMap(dateParser.parse) {
                updatedAt = max(updatedAt, timestamp)
            }

            guard let payload = line.payload else { continue }

            switch line.type {
            case "session_meta":
                if let payloadCwd = payload.cwd, !payloadCwd.isEmpty {
                    cwd = payloadCwd
                }
                if title.isEmpty, let sessionTitle = payload.title, !sessionTitle.isEmpty {
                    title = sessionTitle
                }
                if let started = payload.timestamp.flatMap(dateParser.parse) {
                    startedAt = started
                }
            case "turn_context":
                if let payloadCwd = payload.cwd, !payloadCwd.isEmpty {
                    cwd = payloadCwd
                }
                if let payloadModel = payload.model, !payloadModel.isEmpty {
                    model = payloadModel
                }
            case "event_msg":
                guard payload.type == "token_count" else { continue }
                if let info = payload.info {
                    if let total = info.totalTokenUsage?.totalTokens {
                        totalTokens = total
                    }
                    if let current = info.lastTokenUsage?.totalTokens {
                        currentContextTokens = current
                    }
                    if let window = info.modelContextWindow {
                        contextWindow = window
                    }
                }
                if let parsedRateLimits = makeRateLimits(from: payload.rateLimits) {
                    rateLimits = parsedRateLimits
                }
            default:
                continue
            }
        }

        guard !cwd.isEmpty else { return nil }
        if updatedAt == .distantPast {
            updatedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
        }
        if startedAt == .distantPast {
            startedAt = updatedAt
        }

        return CodexParsedRollout(
            threadID: threadID,
            title: title,
            cwd: cwd,
            model: model,
            updatedAt: updatedAt,
            startedAt: startedAt,
            totalTokens: totalTokens,
            currentContextTokens: currentContextTokens,
            contextWindow: contextWindow,
            rateLimits: rateLimits
        )
    }

    private func makeRolloutEvent(from line: CodexRolloutLine) -> CodexRolloutEvent {
        let payload = line.payload
        let kind: String
        let summary: String

        switch line.type {
        case "session_meta":
            kind = "Session"
            summary = [payload?.source, payload?.cwd]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case "turn_context":
            kind = "Turn"
            summary = [payload?.model, payload?.cwd]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case "event_msg":
            let nestedType = payload?.type ?? "event"
            kind = nestedType == "token_count" ? "Tokens" : "Event"
            if nestedType == "token_count" {
                let totalTokens = payload?.info?.totalTokenUsage?.totalTokens ?? 0
                let outputTokens = payload?.info?.totalTokenUsage?.outputTokens ?? 0
                summary = "total \(totalTokens.formatted(.number.notation(.compactName))) · output \(outputTokens.formatted(.number.notation(.compactName)))"
            } else {
                summary = nestedType
            }
        case "response_item":
            kind = "Response"
            summary = payload?.type ?? "item"
        case "message":
            kind = "Message"
            summary = payload?.role ?? "message"
        default:
            kind = line.type
            summary = ""
        }

        return CodexRolloutEvent(
            id: UUID().uuidString,
            timestamp: line.timestamp.flatMap(dateParser.parse),
            kind: kind,
            summary: summary
        )
    }

    private func threadIDFromRolloutURL(_ url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.split(separator: "-").suffix(5).joined(separator: "-")
    }

    private func makeRateLimits(from info: CodexRateLimitInfo?) -> RateLimits? {
        guard let info else { return nil }
        let limits = RateLimits(
            fiveHour: info.primary.map { RateLimitWindow(usedPercentage: $0.usedPercent, resetsAt: $0.resetsAt) },
            sevenDay: info.secondary.map { RateLimitWindow(usedPercentage: $0.usedPercent, resetsAt: $0.resetsAt) }
        )
        return limits.hasData ? limits : nil
    }
}
