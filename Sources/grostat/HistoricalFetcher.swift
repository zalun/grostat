import Foundation
import GrostatShared

struct FetchSummary {
    var inserted: Int = 0
    var skipped: Int = 0
    var failedDays: [String] = []
    /// True if the batch was aborted mid-way due to a Growatt rate-limit response (code=20).
    var rateLimited: Bool = false
    /// Remaining dates that were not attempted because of the rate limit.
    var remainingDays: [String] = []
}

/// Shared per-day fetch loop used by `query-historical-data` and `backfill`.
///
/// Inserts only timestamps missing from the database (preserves existing rows
/// and their historical `alert` values). Sleeps 60s between calls to respect
/// the API rate limit. On a per-day API error, logs and continues with the next
/// day after a 60s wait — does not abort the batch.
struct HistoricalFetcher {
    let client: GrowattClient
    let db: Database
    let alerts: AlertChecker

    /// Fetch `dates` sequentially.
    /// - Parameter progress: called once per day before the API call with
    ///   `(index, total, date)`.
    func fetchDays(_ dates: [String], progress: (Int, Int, String) -> Void = { _, _, _ in })
        -> FetchSummary
    {
        var summary = FetchSummary()

        for (i, date) in dates.enumerated() {
            progress(i, dates.count, date)

            let readings: [[String: Any]]
            do {
                readings = try client.fetchHistoricalData(date: date)
            } catch {
                if let grostat = error as? GrostatError, case .rateLimited(let msg) = grostat {
                    print("RATE LIMITED (code=20): \(msg)")
                    summary.rateLimited = true
                    summary.remainingDays = Array(dates[i...])
                    return summary
                }
                print("ERROR: \(error.shortDescription)")
                summary.failedDays.append(date)
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
                summary.inserted += inserted
                summary.skipped += skipped
            }

            if i + 1 < dates.count {
                Thread.sleep(forTimeInterval: 60)
            }
        }

        return summary
    }
}
