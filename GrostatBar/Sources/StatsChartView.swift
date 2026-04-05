import Charts
import SwiftUI

struct StatsChartView: View {
    let data: ChartData
    let metric: Metric
    let granularity: Granularity
    @State private var hoverDate: Date?

    private let solarGold = Color(red: 0.95, green: 0.75, blue: 0.2)
    private let coolBlue = Color(red: 0.4, green: 0.6, blue: 0.85)
    private let maxGapSeconds: TimeInterval = 900
    private let voltageCriticalThreshold: Double = 253

    private var zoomsYAxis: Bool {
        switch metric {
        case .voltage, .peakVoltage, .temperature, .peakTemp:
            return true
        default:
            return false
        }
    }

    private var yDomain: ClosedRange<Double> {
        let allValues = (data.primary.map(\.value) + data.comparison.map(\.value)).filter { $0 > 0 }
        guard let minVal = allValues.min(), let maxVal = allValues.max(), maxVal > 0 else {
            return 0...1
        }
        if zoomsYAxis && minVal > maxVal * 0.1 {
            let range = maxVal - minVal
            let padding = max(range * 0.1, 1)
            return max(0, minVal - padding)...(maxVal + padding)
        }
        return 0...(maxVal * 1.05)
    }

    var body: some View {
        Chart {
            if granularity.usesSummaries {
                summaryPrimaryMarks
                summaryComparisonMarks
            } else if metric == .powerPerString {
                powerPerStringMarks
            } else {
                primaryMarks
                comparisonMarks
            }

            if metric == .voltage || metric == .peakVoltage {
                RuleMark(y: .value("Critical", voltageCriticalThreshold))
                    .foregroundStyle(.red.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
            }

            if let hover = hoverDate {
                RuleMark(x: .value("Hover", hover))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel()
                    .font(.system(.caption2, design: .monospaced))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            // Y axis labels are on the left, so plot area starts after them
                            let plotSize = proxy.plotAreaSize
                            let overlayWidth = geo.size.width
                            let leftAxisWidth = overlayWidth - plotSize.width
                            let plotX = location.x - leftAxisWidth
                            guard plotX >= 0 && plotX <= plotSize.width else {
                                hoverDate = nil
                                return
                            }
                            if let date: Date = proxy.value(atX: plotX) {
                                if granularity.usesSummaries {
                                    // Find bar containing cursor, snap to its center
                                    let barSpan: TimeInterval =
                                        granularity == .yearMonthly ? 86400 * 30 : 86400
                                    if let p = data.primary.first(where: {
                                        date >= $0.date
                                            && date < $0.date.addingTimeInterval(barSpan)
                                    }) {
                                        hoverDate = p.date.addingTimeInterval(barSpan / 2)
                                    } else {
                                        hoverDate = nil
                                    }
                                } else {
                                    // Clamp to data range to prevent chart expansion
                                    if let mn = data.primary.first?.date,
                                        let mx = data.primary.last?.date,
                                        date >= mn && date <= mx
                                    {
                                        hoverDate = date
                                    } else {
                                        hoverDate = nil
                                    }
                                }
                            }
                        case .ended:
                            hoverDate = nil
                        }
                    }
            }
        }
        .chartOverlay { proxy in
            if let hover = hoverDate {
                tooltipOverlay(proxy: proxy, hover: hover)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Primary marks

    @ChartContentBuilder
    private var primaryMarks: some ChartContent {
        let segments = segments(data.primary)
        ForEach(Array(segments.enumerated()), id: \.offset) { idx, segment in
            ForEach(segment) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value(metric.label, point.value),
                    series: .value("Series", "pri\(idx)")
                )
                .foregroundStyle(solarGold)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Base", yDomain.lowerBound),
                    yEnd: .value(metric.label, point.value),
                    series: .value("Series", "area\(idx)")
                )
                .foregroundStyle(solarGold.opacity(0.1))
                .interpolationMethod(.catmullRom)

            }
        }
    }

    // MARK: - Comparison marks

    @ChartContentBuilder
    private var comparisonMarks: some ChartContent {
        let segments = segments(data.comparison)
        ForEach(Array(segments.enumerated()), id: \.offset) { idx, segment in
            ForEach(segment) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value(metric.label, point.value),
                    series: .value("Series", "cmp\(idx)")
                )
                .foregroundStyle(coolBlue)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .interpolationMethod(.catmullRom)
            }
        }
    }

    // MARK: - Summary marks (bar charts)

    private func isIncompletePeriod(_ date: Date) -> Bool {
        let cal = Calendar.current
        switch granularity {
        case .day:
            return false
        case .week, .month:
            // Each bar = one day; only today is incomplete
            return cal.isDateInToday(date)
        case .yearWeekly:
            return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        case .yearMonthly:
            return cal.isDate(date, equalTo: Date(), toGranularity: .month)
        }
    }

    @ChartContentBuilder
    private var summaryPrimaryMarks: some ChartContent {
        ForEach(data.primary) { point in
            BarMark(
                x: .value("Date", point.date, unit: granularity == .yearMonthly ? .month : .day),
                yStart: .value("Base", yDomain.lowerBound),
                yEnd: .value(metric.label, point.value)
            )
            .foregroundStyle(isIncompletePeriod(point.date) ? solarGold.opacity(0.5) : solarGold)
            .position(by: .value("Period", "current"))
        }
    }

    @ChartContentBuilder
    private var summaryComparisonMarks: some ChartContent {
        ForEach(data.comparison) { point in
            BarMark(
                x: .value("Date", point.date, unit: granularity == .yearMonthly ? .month : .day),
                yStart: .value("Base", yDomain.lowerBound),
                yEnd: .value(metric.label, point.value)
            )
            .position(by: .value("Period", "comparison"))
            .foregroundStyle(coolBlue.opacity(0.5))
        }
    }

    private func segments(_ points: [DataPoint]) -> [[DataPoint]] {
        guard !points.isEmpty else { return [] }
        if granularity != .day { return [points] }
        var segments: [[DataPoint]] = [[points[0]]]
        for i in 1..<points.count {
            if points[i].date.timeIntervalSince(points[i - 1].date) > maxGapSeconds {
                segments.append([points[i]])
            } else {
                segments[segments.count - 1].append(points[i])
            }
        }
        return segments
    }

    // MARK: - Power per String marks

    @ChartContentBuilder
    private var powerPerStringMarks: some ChartContent {
        let segments = segments(data.primary)
        ForEach(Array(segments.enumerated()), id: \.offset) { idx, segment in
            ForEach(segment) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("String 1", point.value),
                    series: .value("Series", "s1_\(idx)")
                )
                .foregroundStyle(solarGold)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            ForEach(segment.filter { $0.value2 != nil }) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("String 2", point.value2!),
                    series: .value("Series", "s2_\(idx)")
                )
                .foregroundStyle(coolBlue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
        }
    }

    // MARK: - Tooltip

    @ViewBuilder
    private func tooltipOverlay(proxy: ChartProxy, hover: Date) -> some View {
        GeometryReader { geo in
            if let x: CGFloat = proxy.position(forX: hover) {
                let primaryVal = nearestValue(in: data.primary, to: hover)
                let compVal =
                    metric.showsComparison ? nearestValue(in: data.comparison, to: hover) : nil

                VStack(alignment: .leading, spacing: 2) {
                    if let pv = primaryVal {
                        HStack(spacing: 4) {
                            Circle().fill(solarGold).frame(width: 6, height: 6)
                            Text(formatValue(pv, metric: metric))
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    if let cv = compVal {
                        HStack(spacing: 4) {
                            Circle().fill(coolBlue).frame(width: 6, height: 6)
                            Text(formatValue(cv, metric: metric))
                                .font(.system(.caption, design: .monospaced))
                        }
                    } else if metric.showsComparison {
                        HStack(spacing: 4) {
                            Circle().fill(coolBlue.opacity(0.3)).frame(width: 6, height: 6)
                            Text("—")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .fixedSize()
                .position(x: min(max(x, 50), geo.size.width - 50), y: 20)
            }
        }
    }

    private func nearestPoint(in points: [DataPoint], to date: Date) -> DataPoint? {
        guard !points.isEmpty else { return nil }
        let nearest = points.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
        guard let p = nearest, abs(p.date.timeIntervalSince(date)) < 86400 * 32 else { return nil }
        return p
    }

    private func nearestValue(in points: [DataPoint], to date: Date) -> Double? {
        nearestPoint(in: points, to: date)?.value
    }

    private func formatValue(_ v: Double, metric: Metric) -> String {
        String(format: "%.1f %@", v, metric.unit)
    }
}
