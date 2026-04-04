import GrostatShared
import SwiftUI

enum PopoverTab {
    case statistics
    case status
}

struct PopoverContentView: View {
    @Binding var activeTab: PopoverTab
    let periodState: PeriodState
    let dataManager: StatsDataManager
    let reading: InverterReading?
    let config: BarConfig
    let onQuit: () -> Void
    let onDetach: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()

            switch activeTab {
            case .statistics:
                StatsView(
                    periodState: periodState,
                    dataManager: dataManager
                )
            case .status:
                StatusPopover(
                    reading: reading,
                    config: config,
                    onQuit: onQuit
                )
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Statistics", tab: .statistics)
            tabButton("Status", tab: .status)
            Spacer()
            if activeTab == .statistics {
                Button(action: onDetach) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open in window")
                .padding(.trailing, 12)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 12)
    }

    private func tabButton(_ label: String, tab: PopoverTab) -> some View {
        Button(action: { activeTab = tab }) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(activeTab == tab ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    activeTab == tab
                        ? Color.primary.opacity(0.08)
                        : Color.clear
                )
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
