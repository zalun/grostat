import SwiftUI

struct StatsView: View {
    @ObservedObject var periodState: PeriodState
    let dataManager: StatsDataManager

    @AppStorage("stats.leftMetric") private var leftMetricRaw: String = Metric.energy.rawValue
    @AppStorage("stats.rightMetric") private var rightMetricRaw: String = Metric.powerDC.rawValue

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

            if let ld = leftData {
                SummaryCardsView(data: ld)
                    .padding(.vertical, 16)
            }

            HStack(spacing: 16) {
                chartPanel(metric: leftMetric, metricBinding: $leftMetricRaw, data: leftData)
                chartPanel(metric: rightMetric, metricBinding: $rightMetricRaw, data: rightData)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Spacer(minLength: 0)
        }
        .frame(minWidth: 700, minHeight: 450)
        .task { reloadData() }
        .onChange(of: periodState.granularity) { _ in reloadData() }
        .onChange(of: periodState.selectedDate) { _ in reloadData() }
        .onChange(of: periodState.comparisonMode) { _ in reloadData() }
        .onChange(of: leftMetricRaw) { _ in reloadLeftData() }
        .onChange(of: rightMetricRaw) { _ in reloadRightData() }
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

    private func chartPanel(metric: Metric, metricBinding: Binding<String>, data: ChartData?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: metricBinding) {
                    ForEach(Metric.allCases) { m in
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
                StatsChartView(data: d, metric: metric)
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
