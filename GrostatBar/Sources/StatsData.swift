import Foundation

// MARK: - Granularity

enum Granularity: String, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

// MARK: - ComparisonMode

enum ComparisonMode: String, CaseIterable, Identifiable {
    case previousPeriod = "previous"
    case sameLastYear = "lastYear"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .previousPeriod: return "Previous Period"
        case .sameLastYear: return "Same Period Last Year"
        }
    }
}

// MARK: - Metric

enum Metric: String, CaseIterable, Identifiable {
    case energy, powerDC, powerAC, voltage, temperature, powerPerString
    var id: String { rawValue }

    var label: String {
        switch self {
        case .energy: return "Energy"
        case .powerDC: return "Power DC"
        case .powerAC: return "Power AC"
        case .voltage: return "Voltage"
        case .temperature: return "Temperature"
        case .powerPerString: return "Power / String"
        }
    }

    var unit: String {
        switch self {
        case .energy: return "kWh"
        case .powerDC, .powerAC, .powerPerString: return "kW"
        case .voltage: return "V"
        case .temperature: return "°C"
        }
    }

    var showsComparison: Bool {
        self != .powerPerString
    }
}

// MARK: - DataPoint

struct DataPoint: Identifiable {
    let date: Date
    let value: Double
    let value2: Double?
    var id: Date { date }
}

// MARK: - ChartData

struct ChartData {
    let primary: [DataPoint]
    let comparison: [DataPoint]
    let totalEnergy: Double
    let comparisonTotalEnergy: Double
    let peakPower: Double

    var deltaPercent: Double? {
        guard comparisonTotalEnergy > 0 else { return nil }
        return ((totalEnergy - comparisonTotalEnergy) / comparisonTotalEnergy) * 100
    }
}

// MARK: - PeriodRange

struct PeriodRange {
    let start: Date
    let end: Date

    static func primary(for date: Date, granularity: Granularity) -> PeriodRange {
        let cal = Calendar.current
        let start: Date
        let end: Date
        let fallback = cal.startOfDay(for: date)

        switch granularity {
        case .day:
            start = fallback
            end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            start = cal.date(from: comps) ?? fallback
            end = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        case .month:
            let comps = cal.dateComponents([.year, .month], from: date)
            start = cal.date(from: comps) ?? fallback
            end = cal.date(byAdding: .month, value: 1, to: start) ?? start
        case .year:
            let comps = cal.dateComponents([.year], from: date)
            start = cal.date(from: comps) ?? fallback
            end = cal.date(byAdding: .year, value: 1, to: start) ?? start
        }
        return PeriodRange(start: start, end: end)
    }

    func comparison(mode: ComparisonMode, granularity: Granularity) -> PeriodRange {
        let cal = Calendar.current
        let component: Calendar.Component
        switch mode {
        case .previousPeriod: component = granularity.calendarComponent
        case .sameLastYear: component = .year
        }
        let s = cal.date(byAdding: component, value: -1, to: start) ?? start
        let e = cal.date(byAdding: component, value: -1, to: end) ?? end
        return PeriodRange(start: s, end: e)
    }
}

// MARK: - StatsDataManager

final class StatsDataManager {
    private let reader: StatusReader

    init(reader: StatusReader) {
        self.reader = reader
    }

    func load(date: Date, granularity: Granularity, comparisonMode: ComparisonMode, metric: Metric) -> ChartData {
        let pRange = PeriodRange.primary(for: date, granularity: granularity)
        let cRange = pRange.comparison(mode: comparisonMode, granularity: granularity)

        let primaryReadings = reader.readRange(from: pRange.start, to: pRange.end)
        let comparisonReadings = reader.readRange(from: cRange.start, to: cRange.end)

        let primaryPoints = aggregate(readings: primaryReadings, metric: metric, granularity: granularity)
        let comparisonPoints = aggregate(readings: comparisonReadings, metric: metric, granularity: granularity)

        // Rebase comparison points to align with primary period
        let offset = pRange.start.timeIntervalSince(cRange.start)
        let rebasedComparison = comparisonPoints.map { p in
            DataPoint(date: p.date.addingTimeInterval(offset), value: p.value, value2: p.value2)
        }

        let totalEnergy = sumDailyEnergy(readings: primaryReadings)
        let compTotalEnergy = sumDailyEnergy(readings: comparisonReadings)
        let peakPower = primaryReadings.map(\.pac).max().map { $0 / 1000.0 } ?? 0

        return ChartData(
            primary: primaryPoints,
            comparison: rebasedComparison,
            totalEnergy: totalEnergy,
            comparisonTotalEnergy: compTotalEnergy,
            peakPower: peakPower
        )
    }

    /// Sum energy by taking the max powerToday per calendar day, then summing across days.
    /// powerToday is a cumulative counter that resets daily.
    private func sumDailyEnergy(readings: [InverterReading]) -> Double {
        let cal = Calendar.current
        var dailyMax: [DateComponents: Double] = [:]
        for r in readings {
            guard let d = r.date else { continue }
            let dayKey = cal.dateComponents([.year, .month, .day], from: d)
            dailyMax[dayKey] = max(dailyMax[dayKey] ?? 0, r.powerToday)
        }
        return dailyMax.values.reduce(0, +)
    }

    private func aggregate(readings: [InverterReading], metric: Metric, granularity: Granularity) -> [DataPoint] {
        guard !readings.isEmpty else { return [] }

        // For day view, return raw points (no aggregation)
        if granularity == .day {
            return readings.compactMap { r in
                guard let d = r.date else { return nil }
                let (v1, v2) = extractValues(from: r, metric: metric)
                return DataPoint(date: d, value: v1, value2: v2)
            }
        }

        // Group readings into time buckets
        let cal = Calendar.current
        var buckets: [Date: [(Double, Double?)]] = [:]
        for r in readings {
            guard let d = r.date else { continue }
            let comps: DateComponents
            switch granularity {
            case .week:
                comps = cal.dateComponents([.year, .month, .day, .hour], from: d)
            case .month:
                comps = cal.dateComponents([.year, .month, .day], from: d)
            case .year:
                comps = cal.dateComponents([.year, .month], from: d)
            case .day:
                fatalError("Unreachable: day granularity handled above")
            }
            let bucketDate = cal.date(from: comps) ?? d
            let (v1, v2) = extractValues(from: r, metric: metric)
            buckets[bucketDate, default: []].append((v1, v2))
        }

        return buckets.sorted { $0.key < $1.key }.map { (date, values) in
            let aggregated: Double
            let aggregated2: Double?

            switch metric {
            case .energy:
                aggregated = values.map(\.0).max() ?? 0
                aggregated2 = nil
            case .voltage, .temperature:
                aggregated = values.map(\.0).max() ?? 0
                aggregated2 = nil
            case .powerDC, .powerAC:
                aggregated = values.map(\.0).reduce(0, +) / Double(values.count)
                aggregated2 = nil
            case .powerPerString:
                aggregated = values.map(\.0).reduce(0, +) / Double(values.count)
                let v2s = values.compactMap(\.1)
                aggregated2 = v2s.isEmpty ? nil : v2s.reduce(0, +) / Double(v2s.count)
            }

            return DataPoint(date: date, value: aggregated, value2: aggregated2)
        }
    }

    private func extractValues(from r: InverterReading, metric: Metric) -> (Double, Double?) {
        switch metric {
        case .energy:
            return (r.powerToday, nil)
        case .powerDC:
            return (r.ppv / 1000.0, nil)
        case .powerAC:
            return (r.pac / 1000.0, nil)
        case .voltage:
            return (r.vmaxPhase, nil)
        case .temperature:
            return (r.temperature, nil)
        case .powerPerString:
            return (r.ppv1 / 1000.0, r.ppv2 / 1000.0)
        }
    }
}
