import Foundation
import Combine

final class PeriodState: ObservableObject {
    private enum Keys {
        static let granularity = "stats.granularity"
        static let selectedDate = "stats.selectedDate"
        static let comparisonMode = "stats.comparisonMode"
    }

    @Published var granularity: Granularity {
        didSet { UserDefaults.standard.set(granularity.rawValue, forKey: Keys.granularity) }
    }
    @Published var selectedDate: Date {
        didSet { UserDefaults.standard.set(selectedDate.timeIntervalSince1970, forKey: Keys.selectedDate) }
    }
    @Published var comparisonMode: ComparisonMode {
        didSet { UserDefaults.standard.set(comparisonMode.rawValue, forKey: Keys.comparisonMode) }
    }

    init() {
        let g = UserDefaults.standard.string(forKey: Keys.granularity)
            .flatMap { Granularity(rawValue: $0) } ?? .month
        let ts = UserDefaults.standard.double(forKey: Keys.selectedDate)
        let d = ts > 0 ? Date(timeIntervalSince1970: ts) : Date()
        let cm = UserDefaults.standard.string(forKey: Keys.comparisonMode)
            .flatMap { ComparisonMode(rawValue: $0) } ?? .previousPeriod

        self.granularity = g
        self.selectedDate = d
        self.comparisonMode = cm
    }

    func stepForward() {
        selectedDate = step(by: 1)
    }

    func stepBack() {
        selectedDate = step(by: -1)
    }

    private func step(by value: Int) -> Date {
        Calendar.current.date(byAdding: granularity.calendarComponent, value: value, to: selectedDate) ?? selectedDate
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let weekStartFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let weekEndSameMonthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d, yyyy"; return f
    }()
    private static let weekEndCrossMonthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()
    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private static let yearFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy"; return f
    }()

    var periodLabel: String {
        let cal = Calendar.current
        switch granularity {
        case .day:
            return Self.dayFmt.string(from: selectedDate)
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
            let weekStart = cal.date(from: comps) ?? selectedDate
            let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let endFmt = cal.component(.month, from: weekStart) == cal.component(.month, from: weekEnd)
                ? Self.weekEndSameMonthFmt : Self.weekEndCrossMonthFmt
            return "\(Self.weekStartFmt.string(from: weekStart)) – \(endFmt.string(from: weekEnd))"
        case .month:
            return Self.monthFmt.string(from: selectedDate)
        case .year:
            return Self.yearFmt.string(from: selectedDate)
        }
    }
}
