import SwiftUI

struct StatsPopoverView: View {
    let periodState: PeriodState
    let dataManager: StatsDataManager
    let onDetach: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onDetach) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open in window")
                Button(action: onQuit) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit")
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            StatsView(
                periodState: periodState,
                dataManager: dataManager
            )
        }
        .frame(width: 820, height: 520)
    }
}
