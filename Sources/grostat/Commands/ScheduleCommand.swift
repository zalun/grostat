import ArgumentParser
import Foundation

struct ScheduleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schedule",
        abstract: "Install launchd agent to collect data every 5 minutes (6:00-20:00)"
    )

    @Option(name: .long, help: "Interval in minutes (default: 5)")
    var interval: Int = 5

    @Option(name: .long, help: "Start hour (default: 6)")
    var startHour: Int = 6

    @Option(name: .long, help: "End hour (default: 20)")
    var endHour: Int = 20

    func run() throws {
        let plistPath = LaunchAgent.plistPath

        if FileManager.default.fileExists(atPath: plistPath.path) {
            print("Schedule already installed: \(plistPath.path)")
            print("Run 'grostat unschedule' first to remove it.")
            return
        }

        guard let grostatPath = LaunchAgent.findBinary() else {
            throw GrostatError.config("Cannot find grostat binary in PATH")
        }

        let config = Config.load()
        let logDir = (config.resolvedDbPath as NSString).deletingLastPathComponent

        let plist = LaunchAgent.generate(
            binary: grostatPath,
            intervalMinutes: interval,
            startHour: startHour,
            endHour: endHour,
            logDir: logDir
        )

        let dir = plistPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try plist.write(to: plistPath, atomically: true, encoding: .utf8)

        let result = Process.run("/bin/launchctl", arguments: ["load", plistPath.path])
        if result == 0 {
            print("Scheduled: grostat collect every \(interval) min (\(startHour):00-\(endHour):00)")
            print("Plist: \(plistPath.path)")
            print("Logs: \(logDir)/grostat.log")
        } else {
            print("Warning: launchctl load failed. Try manually: launchctl load \(plistPath.path)")
        }
    }
}

struct UnscheduleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unschedule",
        abstract: "Remove launchd agent for grostat"
    )

    func run() throws {
        let plistPath = LaunchAgent.plistPath

        guard FileManager.default.fileExists(atPath: plistPath.path) else {
            print("No schedule found. Nothing to remove.")
            return
        }

        _ = Process.run("/bin/launchctl", arguments: ["unload", plistPath.path])
        try FileManager.default.removeItem(at: plistPath)
        print("Unscheduled. Removed \(plistPath.path)")
    }
}

// MARK: - LaunchAgent helpers

enum LaunchAgent {
    static let label = "com.zalun.grostat"

    static var plistPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func findBinary() -> String? {
        // Check common locations
        let candidates = [
            "/opt/homebrew/bin/grostat",
            "/usr/local/bin/grostat",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // Try which
        let pipe = Pipe()
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["grostat"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let p = path, !p.isEmpty { return p }
        return nil
    }

    static func generate(
        binary: String, intervalMinutes: Int, startHour: Int, endHour: Int, logDir: String
    ) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binary)</string>
                <string>collect</string>
            </array>
            <key>StartInterval</key>
            <integer>\(intervalMinutes * 60)</integer>
            <key>StartCalendarInterval</key>
            <array>
        \(calendarEntries(intervalMinutes: intervalMinutes, startHour: startHour, endHour: endHour))
            </array>
            <key>StandardOutPath</key>
            <string>\(logDir)/grostat.stdout.log</string>
            <key>StandardErrorPath</key>
            <string>\(logDir)/grostat.stderr.log</string>
        </dict>
        </plist>
        """
    }

    private static func calendarEntries(
        intervalMinutes: Int, startHour: Int, endHour: Int
    ) -> String {
        var entries: [String] = []
        for hour in startHour..<endHour {
            var minute = 0
            while minute < 60 {
                entries.append("""
                        <dict>
                            <key>Hour</key>
                            <integer>\(hour)</integer>
                            <key>Minute</key>
                            <integer>\(minute)</integer>
                        </dict>
                """)
                minute += intervalMinutes
            }
        }
        return entries.joined(separator: "\n")
    }
}

extension Process {
    @discardableResult
    static func run(_ path: String, arguments: [String]) -> Int32 {
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
