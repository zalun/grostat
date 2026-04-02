import Foundation

public struct InverterReading: Codable {
    public let timestamp: String

    // DC input (panels)
    public let vpv1: Double
    public let vpv2: Double
    public let ipv1: Double
    public let ipv2: Double
    public let ppv1: Double
    public let ppv2: Double
    public let ppv: Double
    public let epv1Today: Double
    public let epv2Today: Double
    public let epv1Total: Double
    public let epv2Total: Double

    // AC grid — line-to-line
    public let vacr: Double
    public let vacs: Double
    public let vact: Double
    // AC grid — phase (computed)
    public let vacrPhase: Double
    public let vacsPhase: Double
    public let vactPhase: Double
    // AC grid — current
    public let iacr: Double
    public let iacs: Double
    public let iact: Double
    // AC grid — power per phase
    public let pacr: Double
    public let pacs: Double
    public let pact: Double
    // AC grid — totals
    public let pac: Double
    public let rac: Double
    public let pf: Double
    public let fac: Double

    // Temperature
    public let temperature: Double
    public let ipmTemperature: Double

    // Energy
    public let powerToday: Double
    public let powerTotal: Double
    public let timeTotal: Double

    // Diagnostics
    public let status: Int
    public let faultType: Int
    public let pBusVoltage: Double
    public let nBusVoltage: Double
    public let warnCode: Int
    public let warningValue1: Int
    public let warningValue2: Int
    public let realOPPercent: Double

    // Computed
    public let vmaxPhase: Double
    public var alert: String

    public init(
        timestamp: String,
        vpv1: Double, vpv2: Double, ipv1: Double, ipv2: Double,
        ppv1: Double, ppv2: Double, ppv: Double,
        epv1Today: Double, epv2Today: Double, epv1Total: Double, epv2Total: Double,
        vacr: Double, vacs: Double, vact: Double,
        vacrPhase: Double, vacsPhase: Double, vactPhase: Double,
        iacr: Double, iacs: Double, iact: Double,
        pacr: Double, pacs: Double, pact: Double,
        pac: Double, rac: Double, pf: Double, fac: Double,
        temperature: Double, ipmTemperature: Double,
        powerToday: Double, powerTotal: Double, timeTotal: Double,
        status: Int, faultType: Int,
        pBusVoltage: Double, nBusVoltage: Double,
        warnCode: Int, warningValue1: Int, warningValue2: Int,
        realOPPercent: Double,
        vmaxPhase: Double, alert: String
    ) {
        self.timestamp = timestamp
        self.vpv1 = vpv1; self.vpv2 = vpv2
        self.ipv1 = ipv1; self.ipv2 = ipv2
        self.ppv1 = ppv1; self.ppv2 = ppv2; self.ppv = ppv
        self.epv1Today = epv1Today; self.epv2Today = epv2Today
        self.epv1Total = epv1Total; self.epv2Total = epv2Total
        self.vacr = vacr; self.vacs = vacs; self.vact = vact
        self.vacrPhase = vacrPhase; self.vacsPhase = vacsPhase; self.vactPhase = vactPhase
        self.iacr = iacr; self.iacs = iacs; self.iact = iact
        self.pacr = pacr; self.pacs = pacs; self.pact = pact
        self.pac = pac; self.rac = rac; self.pf = pf; self.fac = fac
        self.temperature = temperature; self.ipmTemperature = ipmTemperature
        self.powerToday = powerToday; self.powerTotal = powerTotal; self.timeTotal = timeTotal
        self.status = status; self.faultType = faultType
        self.pBusVoltage = pBusVoltage; self.nBusVoltage = nBusVoltage
        self.warnCode = warnCode
        self.warningValue1 = warningValue1; self.warningValue2 = warningValue2
        self.realOPPercent = realOPPercent
        self.vmaxPhase = vmaxPhase; self.alert = alert
    }

    // MARK: - Helpers

    public static let sqrt3 = sqrt(3.0)

    public static func llToPhase(_ vLL: Double) -> Double {
        guard vLL != 0 else { return 0 }
        return (vLL / sqrt3 * 10).rounded() / 10
    }

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public var date: Date? {
        Self.dateParser.date(from: timestamp)
    }

    public var isStale: Bool {
        guard let d = date else { return true }
        return Date().timeIntervalSince(d) > 900  // 15 minutes
    }

    public var isOffline: Bool {
        guard let d = date else { return true }
        return Date().timeIntervalSince(d) > 3600  // 1 hour
    }

    /// All column names matching the SQLite schema order
    public static let columnNames: [String] = [
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
    public var values: [Any] {
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
