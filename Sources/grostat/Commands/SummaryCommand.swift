import ArgumentParser
import Foundation

struct SummaryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "summary",
        abstract: "Display daily summary of collected data"
    )

    @Argument(help: "Date YYYY-MM-DD (default: today)")
    var date: String?

    func run() throws {
        let config = Config.load()
        let db = try Database(path: config.resolvedDbPath)

        let targetDate: String
        if let d = date {
            targetDate = d
        } else {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            targetDate = f.string(from: Date())
        }

        let rows = db.getReadingsForDate(targetDate)
        if rows.isEmpty {
            print("No data for \(targetDate)")
            return
        }

        let vmaxAll = rows.compactMap { $0["vmax_phase"] as? Double }.max() ?? 0
        let active = rows.compactMap { $0["vmax_phase"] as? Double }.filter { $0 > 0 }
        let vminAll = active.min() ?? 0
        let pacMax = rows.compactMap { $0["pac"] as? Double }.max() ?? 0
        let ppvMax = rows.compactMap { $0["ppv"] as? Double }.max() ?? 0
        let eToday = rows.compactMap { $0["power_today"] as? Double }.max() ?? 0
        let alertCount = rows.filter { ($0["alert"] as? String ?? "") != "" }.count
        let faultCount = rows.filter { ($0["status"] as? Int) == 3 }.count

        let temps = rows.compactMap { $0["temperature"] as? Double }.filter { $0 > 0 }
        let tempRange: String
        if let mn = temps.min(), let mx = temps.max() {
            tempRange = String(format: "%.1f-%.1f", mn, mx)
        } else {
            tempRange = "n/a"
        }

        let vacsVals = rows.compactMap { $0["vacs_phase"] as? Double }.filter { $0 > 0 }
        let vacsAvg =
            vacsVals.isEmpty ? 0 : vacsVals.reduce(0, +) / Double(vacsVals.count)

        let tableRows: [[String]] = [
            ["Vmax phase", String(format: "%.1f V", vmaxAll)],
            ["Vmin phase", String(format: "%.1f V", vminAll)],
            ["Vacs (S) avg", String(format: "%.1f V", vacsAvg)],
            ["PAC max", String(format: "%.0f W", pacMax)],
            ["PPV max (DC)", String(format: "%.0f W", ppvMax)],
            ["Energy today", String(format: "%.1f kWh", eToday)],
            ["Alerts", "\(alertCount)"],
            ["Faults", "\(faultCount)"],
            ["Temp range", "\(tempRange) °C"],
        ]

        Table.print(
            title: "Summary \(targetDate) (\(rows.count) readings)",
            columns: [
                .init(header: "Metric", align: .left),
                .init(header: "Value", align: .right),
            ],
            rows: tableRows)
    }
}
