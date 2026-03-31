import Foundation

struct InverterReading {
    let timestamp: String

    // DC input (panels)
    let vpv1: Double
    let vpv2: Double
    let ipv1: Double
    let ipv2: Double
    let ppv1: Double
    let ppv2: Double
    let ppv: Double
    let epv1Today: Double
    let epv2Today: Double
    let epv1Total: Double
    let epv2Total: Double

    // AC grid — line-to-line
    let vacr: Double
    let vacs: Double
    let vact: Double
    // AC grid — phase (computed)
    let vacrPhase: Double
    let vacsPhase: Double
    let vactPhase: Double
    // AC grid — current
    let iacr: Double
    let iacs: Double
    let iact: Double
    // AC grid — power per phase
    let pacr: Double
    let pacs: Double
    let pact: Double
    // AC grid — totals
    let pac: Double
    let rac: Double
    let pf: Double
    let fac: Double

    // Temperature
    let temperature: Double
    let ipmTemperature: Double

    // Energy
    let powerToday: Double
    let powerTotal: Double
    let timeTotal: Double

    // Diagnostics
    let status: Int
    let faultType: Int
    let pBusVoltage: Double
    let nBusVoltage: Double
    let warnCode: Int
    let warningValue1: Int
    let warningValue2: Int
    let realOPPercent: Double

    // Computed
    let vmaxPhase: Double
    var alert: String

    static let sqrt3 = sqrt(3.0)

    static func llToPhase(_ vLL: Double) -> Double {
        guard vLL != 0 else { return 0 }
        return (vLL / sqrt3 * 10).rounded() / 10
    }

    static func fromAPI(_ data: [String: Any]) -> InverterReading {
        let ts = ISO8601DateFormatter.localFormatter.string(from: Date())

        let vacr = data.double("vacr")
        let vacs = data.double("vacs")
        let vact = data.double("vact")
        let vacrPhase = llToPhase(vacr)
        let vacsPhase = llToPhase(vacs)
        let vactPhase = llToPhase(vact)
        let vmaxPhase = max(vacrPhase, vacsPhase, vactPhase)

        return InverterReading(
            timestamp: ts,
            vpv1: data.double("vpv1"), vpv2: data.double("vpv2"),
            ipv1: data.double("ipv1"), ipv2: data.double("ipv2"),
            ppv1: data.double("ppv1"), ppv2: data.double("ppv2"),
            ppv: data.double("ppv"),
            epv1Today: data.double("epv1Today"), epv2Today: data.double("epv2Today"),
            epv1Total: data.double("epv1Total"), epv2Total: data.double("epv2Total"),
            vacr: vacr, vacs: vacs, vact: vact,
            vacrPhase: vacrPhase, vacsPhase: vacsPhase, vactPhase: vactPhase,
            iacr: data.double("iacr"), iacs: data.double("iacs"), iact: data.double("iact"),
            pacr: data.double("pacr"), pacs: data.double("pacs"), pact: data.double("pact"),
            pac: data.double("pac"), rac: data.double("rac"),
            pf: data.double("pf"), fac: data.double("fac"),
            temperature: data.double("temperature"),
            ipmTemperature: data.double("ipmTemperature"),
            powerToday: data.double("powerToday"), powerTotal: data.double("powerTotal"),
            timeTotal: data.double("timeTotal"),
            status: data.int("status"), faultType: data.int("faultType"),
            pBusVoltage: data.double("pBusVoltage"),
            nBusVoltage: data.double("nBusVoltage"),
            warnCode: data.int("warnCode"),
            warningValue1: data.int("warningValue1"),
            warningValue2: data.int("warningValue2"),
            realOPPercent: data.double("realOPPercent"),
            vmaxPhase: vmaxPhase,
            alert: ""
        )
    }

    /// All column names matching the SQLite schema order
    static let columnNames: [String] = [
        "timestamp",
        "vpv1", "vpv2", "ipv1", "ipv2", "ppv1", "ppv2", "ppv",
        "epv1_today", "epv2_today", "epv1_total", "epv2_total",
        "vacr", "vacs", "vact", "vacr_phase", "vacs_phase", "vact_phase",
        "iacr", "iacs", "iact", "pacr", "pacs", "pact",
        "pac", "rac", "pf", "fac",
        "temperature", "ipm_temperature",
        "power_today", "power_total", "time_total",
        "status", "fault_type",
        "p_bus_voltage", "n_bus_voltage",
        "warn_code", "warning_value1", "warning_value2",
        "real_op_percent",
        "vmax_phase", "alert",
    ]

    /// Values in the same order as columnNames
    var values: [Any] {
        [
            timestamp,
            vpv1, vpv2, ipv1, ipv2, ppv1, ppv2, ppv,
            epv1Today, epv2Today, epv1Total, epv2Total,
            vacr, vacs, vact, vacrPhase, vacsPhase, vactPhase,
            iacr, iacs, iact, pacr, pacs, pact,
            pac, rac, pf, fac,
            temperature, ipmTemperature,
            powerToday, powerTotal, timeTotal,
            status, faultType,
            pBusVoltage, nBusVoltage,
            warnCode, warningValue1, warningValue2,
            realOPPercent,
            vmaxPhase, alert,
        ]
    }
}

// MARK: - Helpers

extension Dictionary where Key == String, Value == Any {
    func double(_ key: String) -> Double {
        if let v = self[key] as? Double { return v }
        if let v = self[key] as? Int { return Double(v) }
        if let v = self[key] as? String, let d = Double(v) { return d }
        return 0
    }

    func int(_ key: String) -> Int {
        if let v = self[key] as? Int { return v }
        if let v = self[key] as? Double { return Int(v) }
        if let v = self[key] as? String, let i = Int(v) { return i }
        return 0
    }
}

extension ISO8601DateFormatter {
    static let localFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}
