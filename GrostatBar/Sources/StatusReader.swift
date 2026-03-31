import Foundation
import SQLite3

struct InverterReading {
    let timestamp: String
    let status: Int
    let ppv: Double
    let pac: Double
    let vmaxPhase: Double
    let vacrPhase: Double
    let vacsPhase: Double
    let vactPhase: Double
    let vpv1: Double
    let vpv2: Double
    let ipv1: Double
    let ipv2: Double
    let ppv1: Double
    let ppv2: Double
    let iacr: Double
    let iacs: Double
    let iact: Double
    let pacr: Double
    let pacs: Double
    let pact: Double
    let pf: Double
    let fac: Double
    let rac: Double
    let temperature: Double
    let ipmTemperature: Double
    let powerToday: Double
    let powerTotal: Double
    let timeTotal: Double
    let faultType: Int
    let warnCode: Int
    let pBusVoltage: Double
    let nBusVoltage: Double
    let realOpPercent: Double
    let epv1Today: Double
    let epv2Today: Double
    let alert: String

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var date: Date? {
        Self.dateParser.date(from: timestamp)
    }

    var isStale: Bool {
        guard let d = date else { return true }
        return Date().timeIntervalSince(d) > 900  // 15 minutes
    }

    var isOffline: Bool {
        guard let d = date else { return true }
        return Date().timeIntervalSince(d) > 3600  // 1 hour
    }
}

final class StatusReader {
    let dbPath: String

    init(dbPath: String) {
        self.dbPath = dbPath
    }

    func readLatest() -> InverterReading? {
        guard FileManager.default.fileExists(atPath: dbPath) else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT * FROM readings ORDER BY id DESC LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        return InverterReading(
            timestamp: col(stmt, "timestamp") ?? "",
            status: intCol(stmt, "status"),
            ppv: dblCol(stmt, "ppv"),
            pac: dblCol(stmt, "pac"),
            vmaxPhase: dblCol(stmt, "vmax_phase"),
            vacrPhase: dblCol(stmt, "vacr_phase"),
            vacsPhase: dblCol(stmt, "vacs_phase"),
            vactPhase: dblCol(stmt, "vact_phase"),
            vpv1: dblCol(stmt, "vpv1"),
            vpv2: dblCol(stmt, "vpv2"),
            ipv1: dblCol(stmt, "ipv1"),
            ipv2: dblCol(stmt, "ipv2"),
            ppv1: dblCol(stmt, "ppv1"),
            ppv2: dblCol(stmt, "ppv2"),
            iacr: dblCol(stmt, "iacr"),
            iacs: dblCol(stmt, "iacs"),
            iact: dblCol(stmt, "iact"),
            pacr: dblCol(stmt, "pacr"),
            pacs: dblCol(stmt, "pacs"),
            pact: dblCol(stmt, "pact"),
            pf: dblCol(stmt, "pf"),
            fac: dblCol(stmt, "fac"),
            rac: dblCol(stmt, "rac"),
            temperature: dblCol(stmt, "temperature"),
            ipmTemperature: dblCol(stmt, "ipm_temperature"),
            powerToday: dblCol(stmt, "power_today"),
            powerTotal: dblCol(stmt, "power_total"),
            timeTotal: dblCol(stmt, "time_total"),
            faultType: intCol(stmt, "fault_type"),
            warnCode: intCol(stmt, "warn_code"),
            pBusVoltage: dblCol(stmt, "p_bus_voltage"),
            nBusVoltage: dblCol(stmt, "n_bus_voltage"),
            realOpPercent: dblCol(stmt, "real_op_percent"),
            epv1Today: dblCol(stmt, "epv1_today"),
            epv2Today: dblCol(stmt, "epv2_today"),
            alert: col(stmt, "alert") ?? ""
        )
    }

    // MARK: - Column helpers

    private func colIndex(_ stmt: OpaquePointer?, _ name: String) -> Int32? {
        let count = sqlite3_column_count(stmt)
        for i in 0..<count {
            if let cName = sqlite3_column_name(stmt, i), String(cString: cName) == name {
                return i
            }
        }
        return nil
    }

    private func col(_ stmt: OpaquePointer?, _ name: String) -> String? {
        guard let i = colIndex(stmt, name),
              let text = sqlite3_column_text(stmt, i)
        else { return nil }
        return String(cString: text)
    }

    private func dblCol(_ stmt: OpaquePointer?, _ name: String) -> Double {
        guard let i = colIndex(stmt, name) else { return 0 }
        return sqlite3_column_double(stmt, i)
    }

    private func intCol(_ stmt: OpaquePointer?, _ name: String) -> Int {
        guard let i = colIndex(stmt, name) else { return 0 }
        return Int(sqlite3_column_int64(stmt, i))
    }
}
