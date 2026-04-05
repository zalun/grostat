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
        let client = GrowattClient(config: config)
        let alerts = AlertChecker(config: config)

        var totalInserted = 0
        var totalSkipped = 0

        for (i, date) in dates.enumerated() {
            print("[\(i + 1)/\(dates.count)] \(date) ... ", terminator: "")
            fflush(stdout)

            let readings: [[String: Any]]
            do {
                readings = try client.fetchHistoricalData(date: date)
            } catch {
                print("ERROR: \(error.shortDescription)")
                if i + 1 < dates.count {
                    print("  Waiting 60s before next request...")
                    Thread.sleep(forTimeInterval: 60)
                }
                continue
            }

            if readings.isEmpty {
                print("no data")
            } else {
                var inserted = 0
                var skipped = 0

                for data in readings {
                    let ts =
                        data["calendar"] as? String
                        ?? data["time"] as? String
                        ?? "\(date) 00:00:00"
                    if db.hasTimestamp(ts) {
                        skipped += 1
                        continue
                    }
                    var reading = InverterReading.fromAPI(data, timestamp: ts)
                    reading.alert = alerts.evaluate(reading)
                    db.insertReading(reading)
                    inserted += 1
                }

                print("\(inserted) inserted, \(skipped) skipped")
                totalInserted += inserted
                totalSkipped += skipped
            }

            if i + 1 < dates.count {
                Thread.sleep(forTimeInterval: 60)
            }
        }

        print("\nDone. Total: \(totalInserted) inserted, \(totalSkipped) duplicates skipped.")
    }
}
