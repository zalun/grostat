import Foundation

/// One day classified as incomplete.
struct GapDay {
    enum Classification {
        case missing  // zero readings
        case partial  // count > 0 but < threshold * monthMax
    }

    let date: String  // YYYY-MM-DD
    let count: Int
    let monthMax: Int  // 0 if month has no data at all
    let classification: Classification

    var ratio: Double {
        monthMax > 0 ? Double(count) / Double(monthMax) : 0
    }
}

/// Range of dates that could be fetched to extend history backwards (before
/// the oldest record in the DB) within the Growatt API window.
struct HistoryExtension {
    let from: String  // YYYY-MM-DD inclusive
    let to: String  // YYYY-MM-DD inclusive
    let dayCount: Int
}

struct GapReport {
    let gaps: [GapDay]
    let historyExtension: HistoryExtension?
    let windowStart: String  // earliest date considered (API limit)
    let windowEnd: String  // latest date considered (yesterday)

    var isEmpty: Bool {
        gaps.isEmpty && historyExtension == nil
    }
}

/// API allows up to ~95 days of historical queries. Use 95 to match the existing
/// `query-historical-data` default.
private let apiWindowDays = 95

struct GapDetector {
    let db: Database
    let today: Date
    let threshold: Double

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    func detect() -> GapReport {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: -1, to: today)!  // exclude today
        let startDate = calendar.date(byAdding: .day, value: -apiWindowDays, to: today)!

        let windowStart = Self.dayFormatter.string(from: startDate)
        let windowEnd = Self.dayFormatter.string(from: endDate)

        let counts = Dictionary(
            uniqueKeysWithValues:
                db.countsByDay(from: windowStart, to: windowEnd)
                .map { ($0.day, $0.count) })
        let monthMaxes = db.monthMaxes(from: windowStart, to: windowEnd)

        // Gap detection only applies from the oldest record onwards. Anything
        // earlier than oldest is offered as "history extension" instead — that's
        // a separate operation with its own UX, and would otherwise show as
        // ~95 lines of "missing" rows that the user can't meaningfully triage.
        let (oldest, _) = db.getDateRange()
        let gapStart: Date
        if let oldestStr = oldest,
            let oldestDate = Self.dayFormatter.date(from: String(oldestStr.prefix(10)))
        {
            gapStart = max(startDate, oldestDate)
        } else {
            // Empty DB: no gap detection, only extension.
            gapStart = calendar.date(byAdding: .day, value: 1, to: endDate)!
        }

        var gaps: [GapDay] = []
        var cursor = gapStart
        while cursor <= endDate {
            let day = Self.dayFormatter.string(from: cursor)
            let month = String(day.prefix(7))
            let count = counts[day] ?? 0
            let monthMax = monthMaxes[month] ?? 0

            if count == 0 {
                gaps.append(
                    GapDay(
                        date: day, count: 0, monthMax: monthMax, classification: .missing))
            } else if monthMax > 0
                && Double(count) < threshold * Double(monthMax)
            {
                gaps.append(
                    GapDay(
                        date: day, count: count, monthMax: monthMax,
                        classification: .partial))
            }

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }

        let historyExtension = computeHistoryExtension(
            windowStart: windowStart, windowEnd: windowEnd)

        return GapReport(
            gaps: gaps,
            historyExtension: historyExtension,
            windowStart: windowStart,
            windowEnd: windowEnd)
    }

    private func computeHistoryExtension(windowStart: String, windowEnd: String)
        -> HistoryExtension?
    {
        let (oldest, _) = db.getDateRange()

        guard let oldest = oldest else {
            // Empty DB: offer the whole window.
            let dayCount = countDaysInclusive(from: windowStart, to: windowEnd) ?? apiWindowDays
            return HistoryExtension(
                from: windowStart, to: windowEnd, dayCount: dayCount)
        }

        // `oldest` is a full timestamp like "2026-02-15 06:00:00"; take the date prefix.
        let oldestDay = String(oldest.prefix(10))

        guard oldestDay > windowStart else {
            // Oldest record at or beyond API limit — nothing to extend.
            return nil
        }

        // Range to fetch: [windowStart, oldestDay - 1 day]
        let calendar = Calendar.current
        guard let oldestDate = Self.dayFormatter.date(from: oldestDay),
            let extendEndDate = calendar.date(byAdding: .day, value: -1, to: oldestDate)
        else { return nil }

        let extendEnd = Self.dayFormatter.string(from: extendEndDate)
        guard let dayCount = countDaysInclusive(from: windowStart, to: extendEnd),
            dayCount > 0
        else { return nil }

        return HistoryExtension(from: windowStart, to: extendEnd, dayCount: dayCount)
    }

    private func countDaysInclusive(from: String, to: String) -> Int? {
        guard let a = Self.dayFormatter.date(from: from),
            let b = Self.dayFormatter.date(from: to),
            a <= b
        else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: a, to: b).day ?? 0
        return days + 1
    }
}

/// Build the list of `YYYY-MM-DD` strings between `from` and `to` inclusive.
/// Useful for callers that need to expand a HistoryExtension into a date list.
func datesInRange(from: String, to: String) -> [String] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    guard let start = formatter.date(from: from),
        let end = formatter.date(from: to),
        start <= end
    else { return [] }

    let calendar = Calendar.current
    var result: [String] = []
    var cursor = start
    while cursor <= end {
        result.append(formatter.string(from: cursor))
        cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
    }
    return result
}
