import AppKit
import GrostatShared
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var reader: ReadingProvider!
    private var config: BarConfig!
    private var timer: Timer?
    private var latestReading: InverterReading?
    private var statsWindow: NSWindow?
    private var periodState = PeriodState()
    private var dataManager: StatsDataManager?
    private var server: GrostatServer?
    private var popoverTab: PopoverTab = .statistics
    private var browser: ServerBrowser?
    private var discoveredServers: [DiscoveredServer] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = BarConfig.load()

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

        // Main menu (needed for CMD+W in LSUIElement apps)
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w")
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu

        // Setup based on mode
        switch config.mode {
        case .local:
            setupLocalMode()
        case .client:
            setupClientMode()
        }
    }

    // MARK: - Mode setup

    private func setupLocalMode() {
        let localReader = StatusReader(dbPath: config.resolvedDbPath)
        reader = localReader

        if config.serverEnabled {
            server = GrostatServer(reader: localReader, config: config)
            server?.start()
        }

        startRefreshLoop()
    }

    private func setupClientMode() {
        showConnectingState()
        if let serverAddr = config.server {
            connectToServer(serverAddr)
        } else {
            startBrowsing()
        }
    }

    private func connectToServer(_ address: String) {
        let parts = address.split(separator: ":")
        let host = String(parts[0])
        let port = parts.count > 1 ? UInt16(parts[1]) ?? 7654 : UInt16(7654)

        let remote = RemoteReader(host: host, port: port)
        remote.onConnectionFailed = { [weak self] in
            self?.handleConnectionFailed()
        }

        // Connect in background to avoid blocking the UI
        DispatchQueue.global().async { [weak self] in
            remote.fetchConfig()
            DispatchQueue.main.async {
                guard let self else { return }
                if let rc = remote.remoteConfig {
                    self.config.deviceSn = rc.deviceSn
                    self.config.ratedPowerW = rc.ratedPowerW
                    self.config.alertWarningV = rc.alertWarningV
                    self.config.alertCriticalV = rc.alertCriticalV
                }
                self.reader = remote
                self.startRefreshLoop()
            }
        }
    }

    private func startBrowsing() {
        showSearchingState()
        browser = ServerBrowser()
        browser?.onUpdate = { [weak self] servers in
            self?.handleServersDiscovered(servers)
        }
        browser?.start()
    }

    private func handleServersDiscovered(_ servers: [DiscoveredServer]) {
        discoveredServers = servers
        if servers.count == 1 {
            showConnectingState(servers[0])
            resolveAndConnect(servers[0])
        } else if servers.count > 1 {
            showFoundState(servers.count)
            // Don't auto-show popover — wait for user click
        }
    }

    private func resolveAndConnect(_ server: DiscoveredServer) {
        // Resolve to get a usable IP address, then connect
        browser?.resolve(server) { [weak self] host, port in
            DispatchQueue.main.async {
                guard let self else { return }
                self.browser?.stop()
                self.browser = nil
                // host from NWConnection may be IPv6 — sanitize for URL use
                var cleanHost = host
                // Remove IPv6 scope ID (e.g., %en0)
                if let pct = cleanHost.firstIndex(of: "%") {
                    cleanHost = String(cleanHost[..<pct])
                }
                // Wrap IPv6 in brackets for URL
                if cleanHost.contains(":") {
                    cleanHost = "[\(cleanHost)]"
                }
                let address = "\(cleanHost):\(port)"
                self.config.server = address
                self.config.save()
                self.connectToServer(address)
            }
        }
    }

    private func handleConnectionFailed() {
        timer?.invalidate()
        timer = nil
        reader = nil
        config.server = nil
        startBrowsing()
    }

    private func showSearchingState() {
        guard let button = statusItem?.button else { return }
        let image = NSImage(systemSymbolName: "bolt.slash.fill", accessibilityDescription: nil)
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.image = image?.withSymbolConfiguration(iconConfig)
        button.image?.isTemplate = true
        button.attributedTitle = NSAttributedString(string: " Searching...")
    }

    private func showFoundState(_ count: Int) {
        guard let button = statusItem?.button else { return }
        let image = NSImage(systemSymbolName: "bolt.slash.fill", accessibilityDescription: nil)
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.image = image?.withSymbolConfiguration(iconConfig)
        button.image?.isTemplate = true
        button.attributedTitle = NSAttributedString(string: " Select server")
    }

    private func showConnectingState(_ server: DiscoveredServer? = nil) {
        guard let button = statusItem?.button else { return }
        let image = NSImage(systemSymbolName: "bolt.slash.fill", accessibilityDescription: nil)
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.image = image?.withSymbolConfiguration(iconConfig)
        button.image?.isTemplate = true
        button.attributedTitle = NSAttributedString(string: " Connecting...")
    }

    // MARK: - Refresh loop

    private func startRefreshLoop() {
        dataManager = StatsDataManager(reader: reader, config: config)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if config.mode == .client && reader == nil {
            // Still browsing — show picker if we have servers
            if !discoveredServers.isEmpty {
                guard let button = statusItem.button else { return }
                let picker = ServerPickerView(servers: discoveredServers) { [weak self] server in
                    self?.popover.performClose(nil)
                    self?.showConnectingState(server)
                    self?.resolveAndConnect(server)
                }
                popover.contentViewController = NSHostingController(rootView: picker)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        } else {
            popoverTab = .statistics
            showPopoverContent()
        }
    }

    private func showPopoverContent() {
        guard let dm = dataManager else { return }
        let tabBinding = Binding<PopoverTab>(
            get: { [weak self] in self?.popoverTab ?? .statistics },
            set: { [weak self] newTab in
                self?.popoverTab = newTab
                self?.updatePopoverSize(for: newTab)
            }
        )
        let view = PopoverContentView(
            activeTab: tabBinding,
            periodState: periodState,
            dataManager: dm,
            reading: latestReading,
            config: config,
            onQuit: { NSApp.terminate(nil) },
            onDetach: { [weak self] in self?.showStatsWindow() }
        )
        popover.contentSize = popoverSize(for: popoverTab)
        popover.contentViewController = NSHostingController(rootView: view)
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func popoverSize(for tab: PopoverTab) -> NSSize {
        switch tab {
        case .statistics: return NSSize(width: 820, height: 520)
        case .status: return NSSize(width: 320, height: 480)
        }
    }

    private func updatePopoverSize(for tab: PopoverTab) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            popover.contentSize = popoverSize(for: tab)
        }
    }

    func showStatsWindow() {
        popover.performClose(nil)

        if let window = statsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let dm = dataManager ?? StatsDataManager(reader: reader, config: config)
        let view = StatsView(periodState: periodState, dataManager: dm)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Statistics"
        window.minSize = NSSize(width: 700, height: 550)
        window.contentViewController = NSHostingController(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false

        // Set app icon for CMD+TAB (loads from CFBundleIconFile in Info.plist)
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
            let icon = NSImage(contentsOfFile: iconPath)
        {
            NSApp.applicationIconImage = icon
        }

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.statsWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }

        statsWindow = window
    }

    private func refresh() {
        latestReading = reader?.readLatest()
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
