import ArgumentParser
import Foundation
import GrostatShared

struct QueryHistoricalDataCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query-historical-data",
        abstract: "Fetch historical data from Growatt API and store in database"
    )

    @Option(name: .long, help: "Start date YYYY-MM-DD (default: 95 days ago)")
    var from: String?

    @Option(name: .long, help: "End date YYYY-MM-DD (default: today)")
    var to: String?

    @Flag(name: .long, help: "Show what would be fetched without making API calls")
    var dryRun = false

    func run() throws {
        let config = Config.load()
        guard !config.token.isEmpty else {
            print("Token not set. Run 'grostat init' and edit config, or set GROSTAT_TOKEN.")
            throw ExitCode.failure
        }
        guard !config.deviceSn.isEmpty else {
            print(
                "Device SN not set. Edit ~/.config/grostat/config.json or set GROSTAT_DEVICE_SN.")
            throw ExitCode.failure
        }

        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let endDate: Date
        if let toStr = to, let d = dateFormatter.date(from: toStr) {
            endDate = d
        } else {
            endDate = Date()
        }

        let startDate: Date
        if let fromStr = from, let d = dateFormatter.date(from: fromStr) {
            startDate = d
        } else {
            startDate = calendar.date(byAdding: .day, value: -95, to: endDate)!
        }

        guard startDate <= endDate else {
            print("Error: --from date must be before --to date.")
            throw ExitCode.failure
        }

        var dates: [String] = []
        var current = startDate
        while current <= endDate {
            dates.append(dateFormatter.string(from: current))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        print("Fetching historical data: \(dates.first!) to \(dates.last!) (\(dates.count) days)")

        if dryRun {
            print("Dry run — no API calls made.")
            return
        }

        config.ensureDbDirectory()
        let db = try Database(path: config.resolvedDbPath)
        let fetcher = HistoricalFetcher(
            client: GrowattClient(config: config),
            db: db,
            alerts: AlertChecker(config: config))

        let summary = fetcher.fetchDays(dates) { i, total, date in
            print("[\(i + 1)/\(total)] \(date) ... ", terminator: "")
            fflush(stdout)
        }

        print(
            "\nDone. Total: \(summary.inserted) inserted, \(summary.skipped) duplicates skipped."
        )
        if summary.rateLimited {
            print(
                "Stopped at Growatt's hourly rate limit. \(summary.remainingDays.count) days remain. Wait ~1h and re-run."
            )
        }
        if !summary.failedDays.isEmpty {
            print("Failed: \(summary.failedDays.joined(separator: ", "))")
        }
    }
}
