import SwiftUI

struct SummaryCardsView: View {
    let data: ChartData

    var body: some View {
        HStack(spacing: 16) {
            card(label: "TOTAL ENERGY", value: String(format: "%.1f", data.totalEnergy), unit: "kWh")
            card(label: "PEAK POWER", value: String(format: "%.1f", data.peakPower), unit: "kW")
            deltaCard
        }
        .padding(.horizontal, 20)
    }

    private func card(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var deltaCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DELTA")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            if let delta = data.deltaPercent {
                let sign = delta >= 0 ? "+" : ""
                let color: Color = delta >= 0 ? .green : .red
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(sign)\(String(format: "%.1f", delta))")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(color)
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("—")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
