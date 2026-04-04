import Foundation
import GrostatShared

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

// MARK: - Alert

struct PeriodAlert: Identifiable {
    enum Severity { case warning, critical }
    let id = UUID()
    let severity: Severity
    let message: String
    let timestamp: String
}

// MARK: - ChartData

struct ChartData {
    let primary: [DataPoint]
    let comparison: [DataPoint]
    let totalEnergy: Double
    let comparisonTotalEnergy: Double
    let peakPower: Double
    let alerts: [PeriodAlert]

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
    private let reader: ReadingProvider
    private let config: BarConfig

    init(reader: ReadingProvider, config: BarConfig) {
        self.reader = reader
        self.config = config
    }

    func load(date: Date, granularity: Granularity, comparisonMode: ComparisonMode, metric: Metric) -> ChartData {
        let pRange = PeriodRange.primary(for: date, granularity: granularity)
        let cRange = pRange.comparison(mode: comparisonMode, granularity: granularity)

        let primaryReadings = reader.readRange(from: pRange.start, to: pRange.end)
        let allComparisonReadings = reader.readRange(from: cRange.start, to: cRange.end)

        // Trim comparison to same time-of-day as latest primary reading
        // so delta compares apples-to-apples (e.g., today at 14:00 vs yesterday at 14:00)
        let comparisonReadings: [InverterReading]
        if let lastPrimary = primaryReadings.last?.date {
            let elapsed = lastPrimary.timeIntervalSince(pRange.start)
            let cutoff = cRange.start.addingTimeInterval(elapsed)
            comparisonReadings = allComparisonReadings.filter { r in
                guard let d = r.date else { return false }
                return d <= cutoff
            }
        } else {
            comparisonReadings = allComparisonReadings
        }

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
        let alerts = detectAlerts(readings: primaryReadings)

        return ChartData(
            primary: primaryPoints,
            comparison: rebasedComparison,
            totalEnergy: totalEnergy,
            comparisonTotalEnergy: compTotalEnergy,
            peakPower: peakPower,
            alerts: alerts
        )
    }

    private func detectAlerts(readings: [InverterReading]) -> [PeriodAlert] {
        var alerts: [PeriodAlert] = []

        // Track voltage spans and fault spans separately
        typealias Span = (severity: PeriodAlert.Severity, start: String, end: String, detail: String)

        // Voltage spans
        var vSeverity: PeriodAlert.Severity? = nil
        var vStart = "", vEnd = "", vMin = 0.0, vMax = 0.0

        // Fault spans
        var faultType: Int = 0
        var fStart = "", fEnd = ""

        func closeVoltageSpan() {
            guard let sev = vSeverity else { return }
            let label = sev == .critical ? "critical" : "warning"
            let threshold = sev == .critical ? config.alertCriticalV : config.alertWarningV
            let time = formatTimeRange(vStart, vEnd)
            alerts.append(PeriodAlert(
                severity: sev,
                message: "\(f0(vMin))–\(f0(vMax))V (\(label) ≥\(f0(threshold))V)",
                timestamp: time
            ))
        }

        func closeFaultSpan() {
            guard faultType != 0 else { return }
            let time = formatTimeRange(fStart, fEnd)
            alerts.append(PeriodAlert(
                severity: .critical,
                message: "\(faultName(faultType)) (\(faultType))",
                timestamp: time
            ))
        }

        for r in readings {
            // Voltage grouping
            let sev: PeriodAlert.Severity?
            if r.vmaxPhase >= config.alertCriticalV {
                sev = .critical
            } else {
                sev = nil
            }

            if sev == vSeverity && sev != nil {
                vEnd = r.timestamp
                vMin = min(vMin, r.vmaxPhase)
                vMax = max(vMax, r.vmaxPhase)
            } else {
                closeVoltageSpan()
                vSeverity = sev
                if sev != nil {
                    vStart = r.timestamp; vEnd = r.timestamp
                    vMin = r.vmaxPhase; vMax = r.vmaxPhase
                }
            }

            // Fault grouping
            if r.faultType != 0 {
                if r.faultType == faultType {
                    fEnd = r.timestamp
                } else {
                    closeFaultSpan()
                    faultType = r.faultType
                    fStart = r.timestamp; fEnd = r.timestamp
                }
            } else if faultType != 0 {
                closeFaultSpan()
                faultType = 0
            }
        }
        closeVoltageSpan()
        closeFaultSpan()

        return alerts
    }

    private func faultName(_ code: Int) -> String {
        switch code {
        case 1: return "Auto test failed"
        case 2: return "No AC connection"
        case 3: return "PV isolation low"
        case 4: return "Residual current high"
        case 5: return "DC output high"
        case 6: return "PV voltage high"
        case 7: return "AC voltage high"
        case 8: return "AC frequency high"
        case 9: return "AC frequency low"
        case 10: return "Temperature high"
        case 24: return "DC injection high"
        case 25: return "Residual current high"
        case 26: return "PV insulation low"
        case 30: return "Grid over-voltage"
        case 31: return "Grid under-voltage"
        case 32: return "Grid over-frequency"
        case 33: return "Grid under-frequency"
        case 34: return "Grid impedance high"
        case 35: return "No grid"
        case 36: return "Grid unbalance"
        case 40: return "DC bus high"
        case 41: return "DC bus low"
        case 42: return "DC bus unbalance"
        case 43: return "GFCI device failure"
        case 44: return "10min grid over-voltage"
        default: return "Fault"
        }
    }

    private func formatTimeRange(_ start: String, _ end: String) -> String {
        let s = String(start.suffix(8).prefix(5))
        let e = String(end.suffix(8).prefix(5))
        return s == e ? s : "\(s)–\(e)"
    }

    private func f0(_ v: Double) -> String {
        String(format: "%.0f", v)
    }

    /// Sum energy per day. powerToday is a cumulative counter that resets daily,
    /// but early morning readings may carry over yesterday's value before reset.
    /// Detect the reset (value drops significantly) and take max after last reset.
    private func sumDailyEnergy(readings: [InverterReading]) -> Double {
        let cal = Calendar.current
        // Group readings by day, preserving order
        var dailyReadings: [DateComponents: [Double]] = [:]
        for r in readings {
            guard let d = r.date else { continue }
            let dayKey = cal.dateComponents([.year, .month, .day], from: d)
            dailyReadings[dayKey, default: []].append(r.powerToday)
        }
        // For each day, find max powerToday after the last reset
        return dailyReadings.values.map { values in
            // Find last reset point (value drops by more than 50%)
            var lastResetIdx = 0
            for i in 1..<values.count {
                if values[i] < values[i - 1] * 0.5 && values[i - 1] > 1 {
                    lastResetIdx = i
                }
            }
            let afterReset = values[lastResetIdx...]
            return afterReset.max() ?? 0
        }.reduce(0, +)
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
