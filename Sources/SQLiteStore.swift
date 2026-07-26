import Foundation
import SQLite3

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/**
 solid-name: SQLQuery
 solid-category: model
 solid-description: Small SQL builder that keeps SELECT/FROM/WHERE/ORDER BY readable in calling code while centralizing query string assembly.
 */
struct SQLQuery {
    let select: [String]
    let from: String
    let `where`: String?
    let orderBy: String?
    let limit: Int?

    init(
        select: [String],
        from: String,
        where: String? = nil,
        orderBy: String? = nil,
        limit: Int? = nil
    ) {
        self.select = select
        self.from = from
        self.where = `where`
        self.orderBy = orderBy
        self.limit = limit
    }

    var sql: String {
        var parts = [
            "SELECT " + select.joined(separator: ", "),
            "FROM \(from)"
        ]

        if let `where`, !`where`.isEmpty {
            parts.append("WHERE \(`where`)")
        }

        if let orderBy, !orderBy.isEmpty {
            parts.append("ORDER BY \(orderBy)")
        }

        if let limit {
            parts.append("LIMIT \(limit)")
        }

        return parts.joined(separator: "\n")
    }
}

/**
 solid-name: SQLiteBinding
 solid-category: model
 solid-description: Typed bind values for SQLite prepared statements.
 */
enum SQLiteBinding {
    case int64(Int64)
    case text(String)
}

/**
 solid-name: SQLiteReading
 solid-category: abstraction
 solid-description: Contract for executing read-only SQLite queries and decoding rows into Decodable models.
 */
protocol SQLiteReading {
    func fetchAll<Row: Decodable>(
        _ type: Row.Type,
        query: SQLQuery,
        bindings: [SQLiteBinding]
    ) -> [Row]

    func fetchOne<Row: Decodable>(
        _ type: Row.Type,
        query: SQLQuery,
        bindings: [SQLiteBinding]
    ) -> Row?

    func fetchAll<Row: Decodable>(
        _ type: Row.Type,
        sql: String,
        bindings: [SQLiteBinding]
    ) -> [Row]

    func fetchOne<Row: Decodable>(
        _ type: Row.Type,
        sql: String,
        bindings: [SQLiteBinding]
    ) -> Row?
}

/**
 solid-name: SQLiteDatabase
 solid-category: service
 solid-description: Minimal read-only SQLite wrapper that decodes aliased columns into Decodable models. This keeps query syntax close to SQL while avoiding manual positional row mapping.
 */
struct SQLiteDatabase: SQLiteReading {
    private let path: String
    private let decoder = JSONDecoder()

    init(path: String) {
        self.path = path
    }

    func fetchAll<Row: Decodable>(
        _ type: Row.Type,
        query: SQLQuery,
        bindings: [SQLiteBinding] = []
    ) -> [Row] {
        fetchAll(type, sql: query.sql, bindings: bindings)
    }

    func fetchOne<Row: Decodable>(
        _ type: Row.Type,
        query: SQLQuery,
        bindings: [SQLiteBinding] = []
    ) -> Row? {
        fetchOne(type, sql: query.sql, bindings: bindings)
    }

    func fetchAll<Row: Decodable>(
        _ type: Row.Type,
        sql: String,
        bindings: [SQLiteBinding] = []
    ) -> [Row] {
        guard let db = openDatabase(),
              let statement = prepare(sql: sql, db: db)
        else { return [] }
        defer {
            sqlite3_finalize(statement)
            sqlite3_close(db)
        }

        bind(bindings, to: statement)

        var result: [Row] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let row = decodeRow(type, from: statement) else { continue }
            result.append(row)
        }
        return result
    }

    func fetchOne<Row: Decodable>(
        _ type: Row.Type,
        sql: String,
        bindings: [SQLiteBinding] = []
    ) -> Row? {
        fetchAll(type, sql: sql, bindings: bindings).first
    }

    private func openDatabase() -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            return nil
        }
        return db
    }

    private func prepare(sql: String, db: OpaquePointer) -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            if let statement { sqlite3_finalize(statement) }
            return nil
        }
        return statement
    }

    private func bind(_ bindings: [SQLiteBinding], to statement: OpaquePointer) {
        for (index, binding) in bindings.enumerated() {
            let parameter = Int32(index + 1)
            switch binding {
            case .int64(let value):
                sqlite3_bind_int64(statement, parameter, value)
            case .text(let value):
                sqlite3_bind_text(statement, parameter, value, -1, sqliteTransientDestructor)
            }
        }
    }

    private func decodeRow<Row: Decodable>(_ type: Row.Type, from statement: OpaquePointer) -> Row? {
        let count = sqlite3_column_count(statement)
        var values: [String: Any] = [:]

        for index in 0..<count {
            let key = sqlite3_column_name(statement, index).map(String.init(cString:)) ?? ""
            values[key] = columnValue(from: statement, at: index)
        }

        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values)
        else { return nil }

        return try? decoder.decode(type, from: data)
    }

    private func columnValue(from statement: OpaquePointer, at index: Int32) -> Any {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(statement, index)
        case SQLITE_FLOAT:
            return sqlite3_column_double(statement, index)
        case SQLITE_TEXT:
            return sqlite3_column_text(statement, index).map(String.init(cString:)) ?? ""
        default:
            return NSNull()
        }
    }
}
