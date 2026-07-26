import Foundation

protocol CodexThreadReading {
    func recentThreads(updatedSince minimumDate: Date) -> [CodexStateThread]
    func thread(id: String) -> CodexStateThread?
    func childThreadIDs(parentThreadID: String) -> [String]
    func allChildThreadIDs() -> Set<String>
}

struct CodexSQLiteThreadStore: CodexThreadReading {
    private let database: SQLiteReading

    init(database: SQLiteReading) {
        self.database = database
    }

    func recentThreads(updatedSince minimumDate: Date) -> [CodexStateThread] {
        let query = SQLQuery(
            select: [
                "id",
                "title",
                "cwd",
                "updated_at",
                "created_at",
                "COALESCE(model, '') AS model",
                "COALESCE(tokens_used, 0) AS tokens_used"
            ],
            from: "threads",
            where: "archived = 0 AND updated_at >= ?",
            orderBy: "updated_at DESC"
        )
        return database
            .fetchAll(CodexThreadRow.self, query: query, bindings: [.int64(Int64(minimumDate.timeIntervalSince1970))])
            .compactMap(makeStateThread)
    }

    func thread(id: String) -> CodexStateThread? {
        let query = SQLQuery(
            select: [
                "id",
                "title",
                "cwd",
                "updated_at",
                "created_at",
                "COALESCE(model, '') AS model",
                "COALESCE(tokens_used, 0) AS tokens_used"
            ],
            from: "threads",
            where: "id = ?",
            limit: 1
        )
        return database
            .fetchOne(CodexThreadRow.self, query: query, bindings: [.text(id)])
            .flatMap(makeStateThread)
    }

    func childThreadIDs(parentThreadID: String) -> [String] {
        let query = SQLQuery(
            select: ["child_thread_id"],
            from: "thread_spawn_edges",
            where: "parent_thread_id = ?",
            orderBy: "rowid DESC"
        )
        return database
            .fetchAll(CodexSpawnEdgeRow.self, query: query, bindings: [.text(parentThreadID)])
            .map(\.childThreadID)
    }

    func allChildThreadIDs() -> Set<String> {
        let query = SQLQuery(
            select: ["child_thread_id"],
            from: "thread_spawn_edges"
        )
        return Set(
            database
                .fetchAll(CodexSpawnEdgeRow.self, query: query, bindings: [])
                .map(\.childThreadID)
        )
    }

    private func makeStateThread(from row: CodexThreadRow) -> CodexStateThread? {
        guard !row.id.isEmpty, !row.cwd.isEmpty else { return nil }
        return CodexStateThread(
            id: row.id,
            title: row.title,
            cwd: row.cwd,
            model: row.model,
            updatedAt: Date(timeIntervalSince1970: row.updatedAt),
            createdAt: Date(timeIntervalSince1970: row.createdAt),
            tokensUsed: row.tokensUsed
        )
    }
}
