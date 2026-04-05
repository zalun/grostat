import SwiftUI

struct StatsView: View {
    @ObservedObject var periodState: PeriodState
    let dataManager: StatsDataManager

    @AppStorage("stats.leftMetric") private var leftMetricRaw: String = Metric.powerDC.rawValue
    @AppStorage("stats.rightMetric") private var rightMetricRaw: String = Metric.voltage.rawValue

    @State private var leftData: ChartData?
    @State private var rightData: ChartData?

    private let solarGold = Color(red: 0.95, green: 0.75, blue: 0.2)
    private let coolBlue = Color(red: 0.4, green: 0.6, blue: 0.85)

    private var leftMetric: Metric {
        Metric(rawValue: leftMetricRaw) ?? .energy
    }
    private var rightMetric: Metric {
        Metric(rawValue: rightMetricRaw) ?? .powerDC
    }

    var body: some View {
        VStack(spacing: 0) {
            PeriodSelector(state: periodState)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    if let ld = leftData {
                        SummaryCardsView(data: ld)
                            .padding(.vertical, 16)

                        if !ld.alerts.isEmpty {
                            alertsBanner(ld.alerts)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                        }
                    }

                    HStack(spacing: 16) {
                        chartPanel(
                            metric: leftMetric, metricBinding: $leftMetricRaw, data: leftData)
                        chartPanel(
                            metric: rightMetric, metricBinding: $rightMetricRaw, data: rightData)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .task { reloadData() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if periodState.granularity == .day
                    && Calendar.current.isDateInToday(periodState.selectedDate)
                {
                    reloadData()
                }
            }
        }
        .onChange(of: periodState.granularity) { _ in
            adjustMetricsForGranularity()
            reloadData()
        }
        .onChange(of: periodState.selectedDate) { _ in reloadData() }
        .onChange(of: periodState.comparisonMode) { _ in reloadData() }
        .onChange(of: leftMetricRaw) { _ in reloadLeftData() }
        .onChange(of: rightMetricRaw) { _ in reloadRightData() }
    }

    private var availableMetrics: [Metric] {
        Metric.metrics(for: periodState.granularity)
    }

    private func adjustMetricsForGranularity() {
        let available = availableMetrics
        if !available.contains(leftMetric) {
            leftMetricRaw = available.first?.rawValue ?? Metric.energy.rawValue
        }
        if !available.contains(rightMetric) {
            rightMetricRaw =
                (available.count > 1 ? available[1] : available.first)?.rawValue
                ?? Metric.energy.rawValue
        }
    }

    private func reloadData() {
        reloadLeftData()
        reloadRightData()
    }

    private func reloadLeftData() {
        leftData = dataManager.load(
            date: periodState.selectedDate,
            granularity: periodState.granularity,
            comparisonMode: periodState.comparisonMode,
            metric: leftMetric
        )
    }

    private func reloadRightData() {
        rightData = dataManager.load(
            date: periodState.selectedDate,
            granularity: periodState.granularity,
            comparisonMode: periodState.comparisonMode,
            metric: rightMetric
        )
    }

    private func chartPanel(metric: Metric, metricBinding: Binding<String>, data: ChartData?)
        -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: metricBinding) {
                    ForEach(availableMetrics) { m in
                        Text(m.label).tag(m.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 140)

                Spacer()

                Text(metric.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let d = data {
                StatsChartView(data: d, metric: metric, granularity: periodState.granularity)
                    .frame(minHeight: 200)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(minHeight: 200)
            }

            legend(metric: metric)
        }
    }

    private func legend(metric: Metric) -> some View {
        HStack(spacing: 16) {
            if metric == .powerPerString {
                legendItem(color: solarGold, label: "String 1", dashed: false)
                legendItem(color: coolBlue, label: "String 2", dashed: false)
            } else {
                legendItem(color: solarGold, label: periodState.periodLabel, dashed: false)
                legendItem(color: coolBlue, label: periodState.comparisonMode.label, dashed: true)
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private func alertsBanner(_ alerts: [PeriodAlert]) -> some View {
        let critCount = alerts.filter { $0.severity == .critical }.count
        let warnCount = alerts.filter { $0.severity == .warning }.count
        let hasCritical = critCount > 0
        let summary: String = [
            critCount > 0 ? "\(critCount) critical" : nil,
            warnCount > 0 ? "\(warnCount) warning" : nil,
        ].compactMap { $0 }.joined(separator: ", ")

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(alerts) { alert in
                    HStack(spacing: 6) {
                        Image(
                            systemName: alert.severity == .critical
                                ? "exclamationmark.triangle.fill"
                                : "exclamationmark.circle.fill"
                        )
                        .foregroundColor(alert.severity == .critical ? .red : .orange)
                        .font(.caption)
                        Text(alert.message)
                            .font(.caption)
                        Spacer()
                        Text(alert.timestamp)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(
                    systemName: hasCritical
                        ? "exclamationmark.triangle.fill"
                        : "exclamationmark.circle.fill"
                )
                .foregroundColor(hasCritical ? .red : .orange)
                .font(.caption)
                Text(summary)
                    .font(.caption)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    hasCritical
                        ? Color.red.opacity(0.1)
                        : Color.orange.opacity(0.1))
        )
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 2)
                .overlay {
                    if dashed {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                            .foregroundColor(color)
                    }
                }
            Text(label)
        }
    }
}
