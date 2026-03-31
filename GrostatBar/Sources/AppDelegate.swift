import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var reader: StatusReader!
    private var config: BarConfig!
    private var timer: Timer?
    private var latestReading: InverterReading?
    private var statsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = BarConfig.load()
        reader = StatusReader(dbPath: config.resolvedDbPath)

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 480)

        // Click handler
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Initial read + timer
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let view = StatusPopover(
                reading: latestReading,
                config: config,
                onQuit: { NSApp.terminate(nil) },
                onStats: { [weak self] in self?.showStatsWindow() }
            )
            popover.contentViewController = NSHostingController(rootView: view)
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    func showStatsWindow() {
        popover.performClose(nil)

        if let window = statsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let periodState = PeriodState()
        let dataManager = StatsDataManager(reader: reader)
        let view = StatsView(periodState: periodState, dataManager: dataManager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Statistics"
        window.minSize = NSSize(width: 700, height: 450)
        window.contentViewController = NSHostingController(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        statsWindow = window
    }

    private func refresh() {
        latestReading = reader.readLatest()
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let state = InverterState.from(reading: latestReading, config: config)

        // Icon
        let image = NSImage(systemSymbolName: state.sfSymbolName, accessibilityDescription: nil)
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.image = image?.withSymbolConfiguration(iconConfig)
        button.image?.isTemplate = true
        button.alphaValue = 1.0

        // Text
        switch state {
        case .sleep, .offline:
            button.attributedTitle = NSAttributedString(string: "")
        case .cloudy, .producing, .onFire, .fault:
            guard let r = latestReading else { break }
            let kw = r.ppv / 1000.0
            let text = String(format: " %.1fkW", kw)
            let level = VoltageLevel.from(vmaxPhase: r.vmaxPhase, config: config)
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: level.color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            ]
            button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
        }
    }
}
