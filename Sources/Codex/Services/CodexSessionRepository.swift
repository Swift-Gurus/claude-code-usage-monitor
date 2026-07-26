import Foundation

protocol CodexSessionListing {
    var homePath: String { get }
    func findActiveSessions(now: Date) -> [CodexSession]
}

protocol CodexSessionInspecting: CodexSessionListing {
    func session(threadID: String, now: Date) -> CodexSession?
    func childSessions(parentThreadID: String, now: Date) -> [CodexSession]
    func rolloutEvents(threadID: String, limit: Int) -> [CodexRolloutEvent]
    func rolloutURL(threadID: String) -> URL?
}

struct CodexSessionRepository: CodexSessionInspecting {
    private let paths: CodexPaths
    private let threadStore: CodexThreadReading
    private let rolloutStore: CodexRolloutReading

    init(
        paths: CodexPaths = CodexPaths(),
        threadStore: CodexThreadReading? = nil,
        rolloutStore: CodexRolloutReading? = nil
    ) {
        self.paths = paths
        self.threadStore = threadStore ?? CodexSQLiteThreadStore(
            database: SQLiteDatabase(path: paths.stateDatabaseURL.path)
        )
        self.rolloutStore = rolloutStore ?? CodexRolloutStore(paths: paths)
    }

    var homePath: String { paths.homePath }

    func session(threadID: String, now: Date = Date()) -> CodexSession? {
        let title = rolloutStore.indexedSessionTitles()[threadID] ?? ""
        let thread = threadStore.thread(id: threadID)
        let rollout = rolloutStore.parsedRollout(threadID: threadID, fallbackTitle: title)
        return mergeSession(thread: thread, rollout: rollout)
    }

    func childSessions(parentThreadID: String, now: Date = Date()) -> [CodexSession] {
        threadStore
            .childThreadIDs(parentThreadID: parentThreadID)
            .compactMap { session(threadID: $0, now: now) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func rolloutEvents(threadID: String, limit: Int = 80) -> [CodexRolloutEvent] {
        rolloutStore.rolloutEvents(threadID: threadID, limit: limit)
    }

    func rolloutURL(threadID: String) -> URL? {
        rolloutStore.rolloutURL(threadID: threadID)
    }

    func findActiveSessions(now: Date = Date()) -> [CodexSession] {
        let recentThreshold: TimeInterval = 15 * 60
        let titlesByID = rolloutStore.indexedSessionTitles()
        let childThreadIDs = threadStore.allChildThreadIDs()
        let recentThreads = threadStore.recentThreads(
            updatedSince: now.addingTimeInterval(-recentThreshold)
        )
        let rolloutByThreadID = rolloutStore.recentParsedRollouts(
            now: now,
            threshold: recentThreshold,
            titlesByID: titlesByID
        )

        var sessions: [CodexSession] = recentThreads.compactMap { thread -> CodexSession? in
            guard !childThreadIDs.contains(thread.id) else { return nil }
            return mergeSession(thread: thread, rollout: rolloutByThreadID[thread.id])
        }

        for (threadID, rollout) in rolloutByThreadID where !sessions.contains(where: { $0.threadID == threadID }) {
            guard !childThreadIDs.contains(threadID) else { continue }
            guard now.timeIntervalSince(rollout.updatedAt) <= recentThreshold else { continue }
            sessions.append(
                CodexSession(
                    threadID: rollout.threadID,
                    title: rollout.title,
                    cwd: rollout.cwd,
                    model: rollout.model,
                    updatedAt: rollout.updatedAt,
                    startedAt: rollout.startedAt,
                    totalTokens: rollout.totalTokens,
                    currentContextTokens: rollout.currentContextTokens,
                    contextWindow: rollout.contextWindow,
                    rateLimits: rollout.rateLimits
                )
            )
        }

        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func mergeSession(thread: CodexStateThread?, rollout: CodexParsedRollout?) -> CodexSession? {
        if let thread {
            return CodexSession(
                threadID: thread.id,
                title: rollout?.title.isEmpty == false ? rollout!.title : thread.title,
                cwd: rollout?.cwd.isEmpty == false ? rollout!.cwd : thread.cwd,
                model: rollout?.model.isEmpty == false ? rollout!.model : thread.model,
                updatedAt: max(thread.updatedAt, rollout?.updatedAt ?? .distantPast),
                startedAt: rollout?.startedAt ?? thread.createdAt,
                totalTokens: max(thread.tokensUsed, rollout?.totalTokens ?? 0),
                currentContextTokens: rollout?.currentContextTokens ?? 0,
                contextWindow: rollout?.contextWindow ?? 0,
                rateLimits: rollout?.rateLimits
            )
        }

        guard let rollout else { return nil }
        return CodexSession(
            threadID: rollout.threadID,
            title: rollout.title,
            cwd: rollout.cwd,
            model: rollout.model,
            updatedAt: rollout.updatedAt,
            startedAt: rollout.startedAt,
            totalTokens: rollout.totalTokens,
            currentContextTokens: rollout.currentContextTokens,
            contextWindow: rollout.contextWindow,
            rateLimits: rollout.rateLimits
        )
    }
}
