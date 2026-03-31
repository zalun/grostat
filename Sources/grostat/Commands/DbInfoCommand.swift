import ArgumentParser
import Foundation

struct DbInfoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "db-info",
        abstract: "Show database info: path, size, row count, date range"
    )

    func run() throws {
        let config = Config.load()
        let dbPath = config.resolvedDbPath
        let db = try Database(path: dbPath)

        let rowCount = db.getRowCount()
        let (first, last) = db.getDateRange()
        let sizeMB = Double(db.fileSize) / (1024 * 1024)

        Table.print(
            title: "Database Info",
            columns: [
                .init(header: "Property", align: .left),
                .init(header: "Value", align: .left),
            ],
            rows: [
                ["Path", dbPath],
                ["Size", String(format: "%.2f MB", sizeMB)],
                ["Rows", "\(rowCount)"],
                ["First reading", first ?? "-"],
                ["Last reading", last ?? "-"],
            ])
    }
}
