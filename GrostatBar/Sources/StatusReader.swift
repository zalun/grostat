import Foundation
import GrostatShared
import os
import SQLite3

private let log = Logger(subsystem: "com.grostat.bar", category: "StatusReader")

final class StatusReader: ReadingProvider {
    let dbPath: String

    init(dbPath: String) {
        self.dbPath = dbPath
    }

    func readLatest() -> InverterReading? {
        guard FileManager.default.fileExists(atPath: dbPath) else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            log.error("Failed to open database at \(self.dbPath): \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT * FROM readings ORDER BY id DESC LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            log.error("Failed to prepare query: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        let map = columnMap(stmt)
        return readingFromRow(stmt, map)
    }

    func readRange(from: Date, to: Date) -> [InverterReading] {
        guard FileManager.default.fileExists(atPath: dbPath) else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            log.error("Failed to open database at \(self.dbPath): \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_close(db)
            return []
        }
        defer { sqlite3_close(db) }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let fromStr = fmt.string(from: from)
        let toStr = fmt.string(from: to)

        let sql = "SELECT * FROM readings WHERE timestamp >= ? AND timestamp < ? ORDER BY timestamp ASC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            log.error("Failed to prepare range query: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, (fromStr as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (toStr as NSString).utf8String, -1, SQLITE_TRANSIENT)

        let map = columnMap(stmt)
        var results: [InverterReading] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(readingFromRow(stmt, map))
        }
        return results
    }

    // MARK: - Column helpers

    private func columnMap(_ stmt: OpaquePointer?) -> [String: Int32] {
        var map: [String: Int32] = [:]
        let count = sqlite3_column_count(stmt)
        for i in 0..<count {
            if let cName = sqlite3_column_name(stmt, i) {
                map[String(cString: cName)] = i
            }
        }
        return map
    }

    private func col(_ stmt: OpaquePointer?, _ name: String, _ map: [String: Int32]) -> String? {
        guard let i = map[name], let text = sqlite3_column_text(stmt, i) else { return nil }
        return String(cString: text)
    }

    private func dbl(_ stmt: OpaquePointer?, _ name: String, _ map: [String: Int32]) -> Double {
        guard let i = map[name] else { return 0 }
        return sqlite3_column_double(stmt, i)
    }

    private func int(_ stmt: OpaquePointer?, _ name: String, _ map: [String: Int32]) -> Int {
        guard let i = map[name] else { return 0 }
        return Int(sqlite3_column_int64(stmt, i))
    }

    private func readingFromRow(_ stmt: OpaquePointer?, _ map: [String: Int32]) -> InverterReading {
        InverterReading(
            timestamp: col(stmt, "timestamp", map) ?? "",
            vpv1: dbl(stmt, "vpv1", map),
            vpv2: dbl(stmt, "vpv2", map),
            ipv1: dbl(stmt, "ipv1", map),
            ipv2: dbl(stmt, "ipv2", map),
            ppv1: dbl(stmt, "ppv1", map),
            ppv2: dbl(stmt, "ppv2", map),
            ppv: dbl(stmt, "ppv", map),
            epv1Today: dbl(stmt, "epv1_today", map),
            epv2Today: dbl(stmt, "epv2_today", map),
            epv1Total: dbl(stmt, "epv1_total", map),
            epv2Total: dbl(stmt, "epv2_total", map),
            vacr: dbl(stmt, "vacr", map),
            vacs: dbl(stmt, "vacs", map),
            vact: dbl(stmt, "vact", map),
            vacrPhase: dbl(stmt, "vacr_phase", map),
            vacsPhase: dbl(stmt, "vacs_phase", map),
            vactPhase: dbl(stmt, "vact_phase", map),
            iacr: dbl(stmt, "iacr", map),
            iacs: dbl(stmt, "iacs", map),
            iact: dbl(stmt, "iact", map),
            pacr: dbl(stmt, "pacr", map),
            pacs: dbl(stmt, "pacs", map),
            pact: dbl(stmt, "pact", map),
            pac: dbl(stmt, "pac", map),
            rac: dbl(stmt, "rac", map),
            pf: dbl(stmt, "pf", map),
            fac: dbl(stmt, "fac", map),
            temperature: dbl(stmt, "temperature", map),
            ipmTemperature: dbl(stmt, "ipm_temperature", map),
            powerToday: dbl(stmt, "power_today", map),
            powerTotal: dbl(stmt, "power_total", map),
            timeTotal: dbl(stmt, "time_total", map),
            status: int(stmt, "status", map),
            faultType: int(stmt, "fault_type", map),
            pBusVoltage: dbl(stmt, "p_bus_voltage", map),
            nBusVoltage: dbl(stmt, "n_bus_voltage", map),
            warnCode: int(stmt, "warn_code", map),
            warningValue1: int(stmt, "warning_value1", map),
            warningValue2: int(stmt, "warning_value2", map),
            realOPPercent: dbl(stmt, "real_op_percent", map),
            vmaxPhase: dbl(stmt, "vmax_phase", map),
            alert: col(stmt, "alert", map) ?? ""
        )
    }
}
