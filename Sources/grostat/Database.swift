import Foundation
import GrostatShared
import SQLite3

final class Database {
    private var db: OpaquePointer?
    let path: String

    init(path: String) throws {
        self.path = path
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw GrostatError.database("Cannot open database at \(path)")
        }
        exec("PRAGMA journal_mode=WAL")
        try createSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    private func createSchema() throws {
        let cols = InverterReading.columnNames.map { name -> String in
            if name == "timestamp" { return "timestamp TEXT NOT NULL" }
            if name == "alert" { return "alert TEXT" }
            if ["status", "fault_type", "warn_code", "warning_value1", "warning_value2"].contains(
                name)
            {
                return "\(name) INTEGER"
            }
            return "\(name) REAL"
        }.joined(separator: ", ")

        exec(
            """
            CREATE TABLE IF NOT EXISTS readings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                \(cols)
            )
            """)
        exec(
            "CREATE INDEX IF NOT EXISTS idx_readings_timestamp ON readings(timestamp)")
        exec(
            "CREATE INDEX IF NOT EXISTS idx_readings_alert ON readings(alert) WHERE alert != ''"
        )
    }

    func insertReading(_ reading: InverterReading) {
        let cols = InverterReading.columnNames.joined(separator: ", ")
        let placeholders = InverterReading.columnNames.map { _ in "?" }.joined(separator: ", ")
        let sql = "INSERT INTO readings (\(cols)) VALUES (\(placeholders))"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Log.error("Failed to prepare insert: \(lastError)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        for (i, value) in reading.values.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case let v as String:
                sqlite3_bind_text(stmt, idx, (v as NSString).utf8String, -1, SQLITE_TRANSIENT)
            case let v as Double:
                sqlite3_bind_double(stmt, idx, v)
            case let v as Int:
                sqlite3_bind_int64(stmt, idx, Int64(v))
            default:
                sqlite3_bind_null(stmt, idx)
            }
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            Log.error("Failed to insert: \(lastError)")
        }
    }

    func getLatest() -> [String: Any]? {
        query("SELECT * FROM readings ORDER BY id DESC LIMIT 1").first
    }

    func getReadingsForDate(_ date: String) -> [[String: Any]] {
        query(
            "SELECT * FROM readings WHERE timestamp LIKE ? ORDER BY timestamp",
            params: ["\(date)%"])
    }

    func hasTimestamp(_ timestamp: String) -> Bool {
        let rows = query(
            "SELECT COUNT(*) as cnt FROM readings WHERE timestamp = ?",
            params: [timestamp])
        return (rows.first?["cnt"] as? Int ?? 0) > 0
    }

    func getRowCount() -> Int {
        let rows = query("SELECT COUNT(*) as cnt FROM readings")
        return rows.first?["cnt"] as? Int ?? 0
    }

    func getDateRange() -> (String?, String?) {
        let rows = query("SELECT MIN(timestamp) as mn, MAX(timestamp) as mx FROM readings")
        guard let row = rows.first else { return (nil, nil) }
        return (row["mn"] as? String, row["mx"] as? String)
    }

    /// Returns one row per day with at least one reading in `[from, to]` (inclusive, `YYYY-MM-DD`).
    ///
    /// Counts **distinct 5-minute slots** in the daytime window 06:00–20:00. This normalises
    /// across collection sources: launchd writes one reading per 5-min slot, while the
    /// Growatt API can return several readings per slot when backfilled. The slot-based
    /// count gives a stable max of 168 per fully-covered day regardless of source.
    func countsByDay(from: String, to: String) -> [(day: String, count: Int)] {
        let rows = query(
            """
            SELECT day, COUNT(DISTINCT slot) AS cnt FROM (
                SELECT substr(timestamp, 1, 10) AS day,
                       (CAST(substr(timestamp, 12, 2) AS INTEGER) * 60
                        + CAST(substr(timestamp, 15, 2) AS INTEGER)) / 5 AS slot
                FROM readings
                WHERE substr(timestamp, 1, 10) BETWEEN ? AND ?
                  AND substr(timestamp, 12, 8) >= '06:00:00'
                  AND substr(timestamp, 12, 8) <  '20:00:00'
            )
            GROUP BY day
            ORDER BY day
            """,
            params: [from, to])
        return rows.compactMap { row in
            guard let day = row["day"] as? String, let cnt = row["cnt"] as? Int else { return nil }
            return (day, cnt)
        }
    }

    /// Returns `YYYY-MM → max daily slot count` (same slot-based count as `countsByDay`).
    func monthMaxes(from: String, to: String) -> [String: Int] {
        let rows = query(
            """
            SELECT month, MAX(cnt) AS mx FROM (
                SELECT substr(day, 1, 7) AS month, day, COUNT(DISTINCT slot) AS cnt FROM (
                    SELECT substr(timestamp, 1, 10) AS day,
                           (CAST(substr(timestamp, 12, 2) AS INTEGER) * 60
                            + CAST(substr(timestamp, 15, 2) AS INTEGER)) / 5 AS slot
                    FROM readings
                    WHERE substr(timestamp, 1, 10) BETWEEN ? AND ?
                      AND substr(timestamp, 12, 8) >= '06:00:00'
                      AND substr(timestamp, 12, 8) <  '20:00:00'
                )
                GROUP BY day
            )
            GROUP BY month
            """,
            params: [from, to])
        var result: [String: Int] = [:]
        for row in rows {
            if let month = row["month"] as? String, let mx = row["mx"] as? Int {
                result[month] = mx
            }
        }
        return result
    }

    func exportReadings(from: String? = nil, to: String? = nil) -> [[String: Any]] {
        var sql = "SELECT * FROM readings"
        var conditions: [String] = []
        var params: [String] = []
        if let f = from {
            conditions.append("timestamp >= ?")
            params.append(f)
        }
        if let t = to {
            conditions.append("timestamp < ?")
            params.append("\(t) 99")
        }
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY timestamp"
        return query(sql, params: params)
    }

    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - Helpers

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func query(_ sql: String, params: [String] = []) -> [[String: Any]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Log.error("Query failed: \(lastError)")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        for (i, param) in params.enumerated() {
            sqlite3_bind_text(
                stmt, Int32(i + 1), (param as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }

        var results: [[String: Any]] = []
        let colCount = sqlite3_column_count(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER:
                    row[name] = Int(sqlite3_column_int64(stmt, i))
                case SQLITE_FLOAT:
                    row[name] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT:
                    row[name] = String(cString: sqlite3_column_text(stmt, i))
                default:
                    row[name] = nil as Any? as Any
                }
            }
            results.append(row)
        }
        return results
    }

    private var lastError: String {
        String(cString: sqlite3_errmsg(db))
    }

    var fileSize: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
    }
}
