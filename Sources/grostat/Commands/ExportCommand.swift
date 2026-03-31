import ArgumentParser
import Foundation

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export readings to CSV"
    )

    @Option(name: .long, help: "Start date YYYY-MM-DD")
    var from: String?

    @Option(name: .long, help: "End date YYYY-MM-DD")
    var to: String?

    @Option(name: [.short, .long], help: "Output file (default: stdout)")
    var output: String?

    func run() throws {
        let config = Config.load()
        let db = try Database(path: config.resolvedDbPath)
        let rows = db.exportReadings(from: from, to: to)

        if rows.isEmpty {
            print("No data to export.")
            return
        }

        let headers = InverterReading.columnNames
        var csv = headers.joined(separator: ",") + "\n"

        for row in rows {
            let line = headers.map { key -> String in
                let val = row[key]
                if let s = val as? String { return "\"\(s)\"" }
                if let d = val as? Double { return String(d) }
                if let i = val as? Int { return String(i) }
                return ""
            }.joined(separator: ",")
            csv += line + "\n"
        }

        if let outputPath = output {
            try csv.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Exported \(rows.count) rows -> \(outputPath)")
        } else {
            Swift.print(csv, terminator: "")
        }
    }
}
