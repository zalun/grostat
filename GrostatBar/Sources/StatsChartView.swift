import SwiftUI
import Charts

struct StatsChartView: View {
    let data: ChartData
    let metric: Metric
    @State private var hoverDate: Date?

    private let solarGold = Color(red: 0.95, green: 0.75, blue: 0.2)
    private let coolBlue = Color(red: 0.4, green: 0.6, blue: 0.85)

    var body: some View {
        Chart {
            if metric == .powerPerString {
                powerPerStringMarks
            } else {
                primaryMarks
                comparisonMarks
            }

            if let hover = hoverDate {
                RuleMark(x: .value("Hover", hover))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
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
                            if let date: Date = proxy.value(atX: location.x) {
                                hoverDate = date
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
        ForEach(data.primary) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value(metric.label, point.value),
                series: .value("Series", "primary")
            )
            .foregroundStyle(solarGold)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Time", point.date),
                y: .value(metric.label, point.value)
            )
            .foregroundStyle(solarGold.opacity(0.1))
            .interpolationMethod(.catmullRom)
        }
    }

    // MARK: - Comparison marks

    @ChartContentBuilder
    private var comparisonMarks: some ChartContent {
        ForEach(data.comparison) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value(metric.label, point.value),
                series: .value("Series", "comparison")
            )
            .foregroundStyle(coolBlue)
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .interpolationMethod(.catmullRom)
        }
    }

    // MARK: - Power per String marks

    @ChartContentBuilder
    private var powerPerStringMarks: some ChartContent {
        ForEach(data.primary) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value("String 1", point.value),
                series: .value("Series", "String 1")
            )
            .foregroundStyle(solarGold)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
        }
        ForEach(data.primary) { point in
            if let v2 = point.value2 {
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("String 2", v2),
                    series: .value("Series", "String 2")
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
                let compVal = metric.showsComparison ? nearestValue(in: data.comparison, to: hover) : nil

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
                .position(x: min(max(x, 40), geo.size.width - 40), y: 20)
            }
        }
    }

    private func nearestValue(in points: [DataPoint], to date: Date) -> Double? {
        guard !points.isEmpty else { return nil }
        let nearest = points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
        guard let p = nearest, abs(p.date.timeIntervalSince(date)) < 86400 else { return nil }
        return p.value
    }

    private func formatValue(_ v: Double, metric: Metric) -> String {
        String(format: "%.1f %@", v, metric.unit)
    }
}
