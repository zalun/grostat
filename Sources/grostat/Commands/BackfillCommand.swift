import ArgumentParser
import Foundation
import GrostatShared

struct BackfillCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backfill",
        abstract: "Detect and fill data gaps interactively"
    )

    @Flag(name: .long, help: "List detected gaps and exit without prompting or fetching")
    var dryRun = false

    @Option(
        name: .long,
        help:
            "Ratio of the month's best day below which a day counts as a gap (default 0.7, range 0.0–1.0)"
    )
    var threshold: Double = 0.7

    func run() throws {
        guard threshold >= 0 && threshold <= 1 else {
            print("--threshold must be between 0.0 and 1.0")
            throw ExitCode.failure
        }

        let config = Config.load()
        config.ensureDbDirectory()
        let db = try Database(path: config.resolvedDbPath)

        let detector = GapDetector(db: db, today: Date(), threshold: threshold)
        let report = detector.detect()

        if report.isEmpty {
            print(
                "No gaps found in the last 95 days (\(report.windowStart) → \(report.windowEnd)).")
            return
        }

        if dryRun {
            printDryRun(report)
            return
        }

        // Fail fast if we can't start the TUI — gives a clearer message than
        // the token error below for users who piped stdin.
        guard isatty(STDIN_FILENO) != 0 else {
            print(TUI.TUIError.notATTY.errorDescription ?? "Not a TTY.")
            throw ExitCode.failure
        }

        // Token / device SN only needed for the fetch branch.
        guard !config.token.isEmpty else {
            print("Token not set. Run 'grostat init' and edit config, or set GROSTAT_TOKEN.")
            throw ExitCode.failure
        }
        guard !config.deviceSn.isEmpty else {
            print(
                "Device SN not set. Edit ~/.config/grostat/config.json or set GROSTAT_DEVICE_SN.")
            throw ExitCode.failure
        }

        let selection = try runInteractive(report: report)
        guard let selection = selection, !selection.isEmpty else {
            if selection == nil {
                print("Aborted.")
            } else {
                print("Nothing selected.")
            }
            return
        }

        let dates = expandSelection(selection)
        print(
            "Fetching \(dates.count) days (estimated ~\(estimatedMinutes(dates.count)) min with 60s throttle)..."
        )

        let fetcher = HistoricalFetcher(
            client: GrowattClient(config: config),
            db: db,
            alerts: AlertChecker(config: config))

        let summary = fetcher.fetchDays(dates) { i, total, date in
            print("[\(i + 1)/\(total)] \(date) ... ", terminator: "")
            fflush(stdout)
        }

        print(
            "\nDone. Total: \(summary.inserted) inserted, \(summary.skipped) duplicates skipped.")
        if summary.rateLimited {
            print(
                "Stopped at Growatt's rate limit (~15 req/h on historical endpoint). \(summary.remainingDays.count) days remain."
            )
            print(
                "Wait ~1 hour and run `grostat backfill` again — already-fetched days will be skipped."
            )
        }
        if !summary.failedDays.isEmpty {
            print("Failed: \(summary.failedDays.joined(separator: ", "))")
        }
    }

    // MARK: - Dry run

    private func printDryRun(_ report: GapReport) {
        if !report.gaps.isEmpty {
            print("Found \(report.gaps.count) incomplete day(s):")
            for gap in report.gaps {
                print("  \(renderGapLine(gap))")
            }
        }
        if let ext = report.historyExtension {
            print("")
            print("History extension available:")
            print("  \(renderExtensionLine(ext))")
        }
    }

    // MARK: - Interactive

    private enum SelectionItem {
        case gap(GapDay)
        case historyExtension(HistoryExtension)
    }

    private func runInteractive(report: GapReport) throws -> [SelectionItem]? {
        var items: [SelectionItem] = report.gaps.map { .gap($0) }
        if let ext = report.historyExtension {
            items.append(.historyExtension(ext))
        }

        return try TUI.selectMany(
            items: items,
            render: { item, selected, _ in
                let box = selected ? "[x]" : "[ ]"
                switch item {
                case .gap(let gap):
                    return "\(box) \(renderGapLine(gap))"
                case .historyExtension(let ext):
                    return "\(box) \(renderExtensionLine(ext))"
                }
            },
            footer: { chosen in
                let dayCount = chosen.reduce(0) { acc, item in
                    switch item {
                    case .gap: return acc + 1
                    case .historyExtension(let ext): return acc + ext.dayCount
                    }
                }
                return
                    "\(chosen.count) selected — \(dayCount) API calls — ~\(estimatedMinutes(dayCount)) min (60s throttle)"
            })
    }

    private func expandSelection(_ items: [SelectionItem]) -> [String] {
        var dates: [String] = []
        for item in items {
            switch item {
            case .gap(let gap):
                dates.append(gap.date)
            case .historyExtension(let ext):
                dates.append(contentsOf: datesInRange(from: ext.from, to: ext.to))
            }
        }
        return dates
    }

    // MARK: - Rendering

    private func renderGapLine(_ gap: GapDay) -> String {
        let pct = Int((gap.ratio * 100).rounded())
        switch gap.classification {
        case .missing:
            let baseline = gap.monthMax > 0 ? " / ~\(gap.monthMax)" : ""
            return "\(gap.date)  missing   0\(baseline) readings"
        case .partial:
            return
                "\(gap.date)  partial  \(formatCount(gap.count, monthMax: gap.monthMax)) (\(pct)%)"
        }
    }

    private func formatCount(_ count: Int, monthMax: Int) -> String {
        let cStr = String(count).leftPad(3)
        let mStr = String(monthMax).leftPad(3)
        return "\(cStr) / \(mStr) readings"
    }

    private func renderExtensionLine(_ ext: HistoryExtension) -> String {
        "extend history: \(ext.from) → \(ext.to) (\(ext.dayCount) days before oldest record)"
    }

    private func estimatedMinutes(_ days: Int) -> Int {
        // 60s throttle between calls plus a few seconds for the call itself.
        // For N days the wait is (N-1)*60s. Round up to whole minutes.
        guard days > 1 else { return days }
        let seconds = (days - 1) * 60 + days * 5
        return (seconds + 59) / 60
    }
}
