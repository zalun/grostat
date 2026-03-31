import ArgumentParser
import Foundation

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Display the most recent reading"
    )

    func run() throws {
        let config = Config.load()
        let db = try Database(path: config.resolvedDbPath)

        guard let row = db.getLatest() else {
            print("No readings yet. Run 'grostat collect' first.")
            return
        }

        let alert = row["alert"] as? String ?? ""
        let ts = row["timestamp"] as? String ?? "?"
        print("\nLast reading: \(ts)  \(alert.isEmpty ? "OK" : alert)")

        let groups: [(String, [(String, String)])] = [
            ("DC Input", [
                ("vpv1", "V"), ("vpv2", "V"), ("ipv1", "A"), ("ipv2", "A"),
                ("ppv1", "W"), ("ppv2", "W"), ("ppv", "W"),
                ("epv1_today", "kWh"), ("epv2_today", "kWh"),
            ]),
            ("AC Grid", [
                ("vacr_phase", "V"), ("vacs_phase", "V"), ("vact_phase", "V"),
                ("vmax_phase", "V"),
                ("iacr", "A"), ("iacs", "A"), ("iact", "A"),
                ("pacr", "W"), ("pacs", "W"), ("pact", "W"),
                ("pac", "W"), ("rac", "W"), ("pf", ""), ("fac", "Hz"),
            ]),
            ("Temperature", [
                ("temperature", "°C"), ("ipm_temperature", "°C"),
            ]),
            ("Energy", [
                ("power_today", "kWh"), ("power_total", "kWh"), ("time_total", "h"),
            ]),
            ("Diagnostics", [
                ("status", ""), ("fault_type", ""), ("warn_code", ""),
                ("p_bus_voltage", "V"), ("n_bus_voltage", "V"),
                ("real_op_percent", "%"),
            ]),
        ]

        for (groupName, fields) in groups {
            let rows = fields.map { field, unit -> [String] in
                let val = row[field]
                let formatted: String
                if let d = val as? Double {
                    formatted = String(format: "%.1f", d)
                } else if let i = val as? Int {
                    formatted = "\(i)"
                } else {
                    formatted = "\(val ?? "")"
                }
                return [field, "\(formatted) \(unit)".trimmingCharacters(in: .whitespaces)]
            }
            Table.print(
                title: groupName,
                columns: [
                    .init(header: "Field", align: .left),
                    .init(header: "Value", align: .right),
                ],
                rows: rows)
        }
    }
}
