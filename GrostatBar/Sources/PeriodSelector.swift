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
                    .frame(minWidth: 160)

                Button(action: state.stepForward) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }

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
