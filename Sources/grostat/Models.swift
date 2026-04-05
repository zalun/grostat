import Foundation
import GrostatShared

extension InverterReading {
    static func fromAPI(_ data: [String: Any], timestamp: String? = nil) -> InverterReading {
        let ts = timestamp ?? ISO8601DateFormatter.localFormatter.string(from: Date())

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
