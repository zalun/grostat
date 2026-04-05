import Foundation
import GrostatShared

// MARK: - Granularity

enum Granularity: String, CaseIterable, Identifiable {
    case day, week, month, yearWeekly, yearMonthly
    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .yearWeekly: return "Year-W"
        case .yearMonthly: return "Year-M"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .yearWeekly, .yearMonthly: return .year
        }
    }

    var usesSummaries: Bool {
        self != .day
    }

    var summaryEndpoint: String? {
        switch self {
        case .day: return nil
        case .week, .month: return "summary/daily"
        case .yearWeekly: return "summary/weekly"
        case .yearMonthly: return "summary/monthly"
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
    // Day view metrics
    case energy, powerDC, powerAC, voltage, temperature, powerPerString
    // Summary view metrics
    case peakPower, peakVoltage, peakTemp

    var id: String { rawValue }

    var label: String {
        switch self {
        case .energy: return "Energy"
        case .powerDC: return "Power DC"
        case .powerAC: return "Power AC"
        case .voltage: return "Voltage"
        case .temperature: return "Temperature"
        case .powerPerString: return "Power / String"
        case .peakPower: return "Peak Power"
        case .peakVoltage: return "Peak Voltage"
        case .peakTemp: return "Peak Temp"
        }
    }

    var unit: String {
        switch self {
        case .energy: return "kWh"
        case .powerDC, .powerAC, .powerPerString, .peakPower: return "kW"
        case .voltage, .peakVoltage: return "V"
        case .temperature, .peakTemp: return "°C"
        }
    }

    var showsComparison: Bool {
        self != .powerPerString
    }

    static let dayMetrics: [Metric] = [
        .energy, .powerDC, .powerAC, .voltage, .temperature, .powerPerString,
    ]
    static let summaryMetrics: [Metric] = [.energy, .peakPower, .peakVoltage, .peakTemp]

    static func metrics(for granularity: Granularity) -> [Metric] {
        granularity.usesSummaries ? summaryMetrics : dayMetrics
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
        case .yearWeekly, .yearMonthly:
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

    func load(date: Date, granularity: Granularity, comparisonMode: ComparisonMode, metric: Metric)
        -> ChartData
    {
        if granularity.usesSummaries {
            return loadSummary(
                date: date, granularity: granularity, comparisonMode: comparisonMode, metric: metric
            )
        } else {
            return loadDay(date: date, comparisonMode: comparisonMode, metric: metric)
        }
    }

    private func loadDay(date: Date, comparisonMode: ComparisonMode, metric: Metric) -> ChartData {
        let pRange = PeriodRange.primary(for: date, granularity: .day)
        let cRange = pRange.comparison(mode: comparisonMode, granularity: .day)

        let primaryReadings = reader.readRange(from: pRange.start, to: pRange.end)
        let allComparisonReadings = reader.readRange(from: cRange.start, to: cRange.end)

        // Trim comparison to same time-of-day as latest primary reading
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

        let primaryPoints = rawDataPoints(readings: primaryReadings, metric: metric)
        let comparisonPoints = rawDataPoints(readings: comparisonReadings, metric: metric)

        let offset = pRange.start.timeIntervalSince(cRange.start)
        let rebasedComparison = comparisonPoints.map { p in
            DataPoint(date: p.date.addingTimeInterval(offset), value: p.value, value2: p.value2)
        }

        return ChartData(
            primary: primaryPoints,
            comparison: rebasedComparison,
            totalEnergy: sumDailyEnergy(readings: primaryReadings),
            comparisonTotalEnergy: sumDailyEnergy(readings: comparisonReadings),
            peakPower: primaryReadings.map(\.pac).max().map { $0 / 1000.0 } ?? 0,
            alerts: detectAlerts(readings: primaryReadings)
        )
    }

    private func loadSummary(
        date: Date, granularity: Granularity, comparisonMode: ComparisonMode, metric: Metric
    ) -> ChartData {
        let pRange = PeriodRange.primary(for: date, granularity: granularity)
        let cRange = pRange.comparison(mode: comparisonMode, granularity: granularity)

        let primarySummaries = fetchSummaries(range: pRange, granularity: granularity)
        let comparisonSummaries = fetchSummaries(range: cRange, granularity: granularity)

        let primaryPoints = summaryDataPoints(summaries: primarySummaries, metric: metric)
        let comparisonPoints = summaryDataPoints(summaries: comparisonSummaries, metric: metric)

        let offset = pRange.start.timeIntervalSince(cRange.start)
        let rebasedComparison = comparisonPoints.map { p in
            DataPoint(date: p.date.addingTimeInterval(offset), value: p.value, value2: p.value2)
        }

        let totalEnergy = primarySummaries.map(\.totalEnergy).reduce(0, +)
        let compTotalEnergy = comparisonSummaries.map(\.totalEnergy).reduce(0, +)
        let peakPower = primarySummaries.map(\.peakPowerAC).max() ?? 0

        return ChartData(
            primary: primaryPoints,
            comparison: rebasedComparison,
            totalEnergy: totalEnergy,
            comparisonTotalEnergy: compTotalEnergy,
            peakPower: peakPower,
            alerts: []
        )
    }

    private func fetchSummaries(range: PeriodRange, granularity: Granularity) -> [PeriodSummary] {
        if let remote = reader as? RemoteReader, let endpoint = granularity.summaryEndpoint {
            return remote.fetchSummaries(endpoint: endpoint, from: range.start, to: range.end)
        }
        // Local mode: always compute from raw readings via daily summaries
        let dailies = reader.readDailySummaries(from: range.start, to: range.end)
        switch granularity {
        case .day:
            return []
        case .week, .month:
            return dailies
        case .yearWeekly:
            return aggregateLocal(dailies, components: [.yearForWeekOfYear, .weekOfYear])
        case .yearMonthly:
            return aggregateLocal(dailies, components: [.year, .month])
        }
    }

    private func aggregateLocal(_ summaries: [PeriodSummary], components: Set<Calendar.Component>)
        -> [PeriodSummary]
    {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        var grouped: [(key: DateComponents, items: [PeriodSummary])] = []
        var currentKey: DateComponents?
        var currentItems: [PeriodSummary] = []

        for s in summaries {
            guard let d = s.date else { continue }
            let key = cal.dateComponents(components, from: d)
            if key == currentKey {
                currentItems.append(s)
            } else {
                if let k = currentKey, !currentItems.isEmpty {
                    grouped.append((key: k, items: currentItems))
                }
                currentKey = key
                currentItems = [s]
            }
        }
        if let k = currentKey, !currentItems.isEmpty {
            grouped.append((key: k, items: currentItems))
        }

        return grouped.compactMap { (key, items) in
            guard let periodDate = cal.date(from: key) else { return nil }
            return PeriodSummary(
                periodStart: fmt.string(from: periodDate),
                totalEnergy: items.map(\.totalEnergy).reduce(0, +),
                peakPowerAC: items.map(\.peakPowerAC).max() ?? 0,
                peakPowerDC: items.map(\.peakPowerDC).max() ?? 0,
                peakVoltage: items.map(\.peakVoltage).max() ?? 0,
                maxTemperature: items.map(\.maxTemperature).max() ?? 0,
                peakPpv1: items.map(\.peakPpv1).max() ?? 0,
                peakPpv2: items.map(\.peakPpv2).max() ?? 0
            )
        }
    }

    private func detectAlerts(readings: [InverterReading]) -> [PeriodAlert] {
        var alerts: [PeriodAlert] = []

        // Track voltage spans and fault spans separately
        typealias Span = (
            severity: PeriodAlert.Severity, start: String, end: String, detail: String
        )

        // Voltage spans
        var vSeverity: PeriodAlert.Severity? = nil
        var vStart = ""
        var vEnd = ""
        var vMin = 0.0
        var vMax = 0.0

        // Fault spans
        var faultType: Int = 0
        var fStart = ""
        var fEnd = ""

        func closeVoltageSpan() {
            guard let sev = vSeverity else { return }
            let label = sev == .critical ? "critical" : "warning"
            let threshold = sev == .critical ? config.alertCriticalV : config.alertWarningV
            let time = formatTimeRange(vStart, vEnd)
            alerts.append(
                PeriodAlert(
                    severity: sev,
                    message: "\(f0(vMin))–\(f0(vMax))V (\(label) ≥\(f0(threshold))V)",
                    timestamp: time
                ))
        }

        func closeFaultSpan() {
            guard faultType != 0 else { return }
            let time = formatTimeRange(fStart, fEnd)
            alerts.append(
                PeriodAlert(
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
                    vStart = r.timestamp
                    vEnd = r.timestamp
                    vMin = r.vmaxPhase
                    vMax = r.vmaxPhase
                }
            }

            // Fault grouping
            if r.faultType != 0 {
                if r.faultType == faultType {
                    fEnd = r.timestamp
                } else {
                    closeFaultSpan()
                    faultType = r.faultType
                    fStart = r.timestamp
                    fEnd = r.timestamp
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

    private func rawDataPoints(readings: [InverterReading], metric: Metric) -> [DataPoint] {
        readings.compactMap { r in
            guard let d = r.date else { return nil }
            let (v1, v2) = extractValues(from: r, metric: metric)
            return DataPoint(date: d, value: v1, value2: v2)
        }
    }

    private func summaryDataPoints(summaries: [PeriodSummary], metric: Metric) -> [DataPoint] {
        summaries.compactMap { s in
            guard let d = s.date else { return nil }
            let value: Double
            switch metric {
            case .energy: value = s.totalEnergy
            case .peakPower: value = s.peakPowerAC
            case .peakVoltage: value = s.peakVoltage
            case .peakTemp: value = s.maxTemperature
            // Day-only metrics shouldn't appear in summary views, but handle gracefully
            case .powerDC: value = s.peakPowerDC
            case .powerAC: value = s.peakPowerAC
            case .voltage: value = s.peakVoltage
            case .temperature: value = s.maxTemperature
            case .powerPerString: value = s.peakPpv1
            }
            return DataPoint(date: d, value: value, value2: nil)
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
        case .voltage, .peakVoltage:
            return (r.vmaxPhase, nil)
        case .temperature, .peakTemp:
            return (r.temperature, nil)
        case .powerPerString:
            return (r.ppv1 / 1000.0, r.ppv2 / 1000.0)
        case .peakPower:
            return (r.pac / 1000.0, nil)
        }
    }
}
