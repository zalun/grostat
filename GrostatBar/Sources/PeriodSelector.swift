import SwiftUI

struct PeriodSelector: View {
    @ObservedObject var state: PeriodState

    var body: some View {
        HStack(spacing: 12) {
            Picker("", selection: $state.granularity) {
                ForEach(Granularity.allCases) { g in
                    Text(g.label).tag(g)
                }
            }
            .labelsHidden()
            .frame(width: 90)

            HStack(spacing: 4) {
                Button(action: state.stepBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text(state.periodLabel)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .frame(minWidth: 200)

                Button(action: state.stepForward) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }

            Button(action: state.goToCurrent) {
                Text("Today")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(state.isCurrentPeriod)
            .opacity(state.isCurrentPeriod ? 0.3 : 1.0)

            Text("vs")
                .foregroundColor(.secondary)

            Picker("", selection: $state.comparisonMode) {
                ForEach(ComparisonMode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .labelsHidden()
            .frame(width: 180)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
