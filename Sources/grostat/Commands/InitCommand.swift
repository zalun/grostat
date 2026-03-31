import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create config and set up token and device serial number"
    )

    func run() throws {
        if FileManager.default.fileExists(atPath: Config.configFile.path) {
            print("Config already exists: \(Config.configFile.path)")
            print("Edit it directly, or delete it and run 'grostat init' again.")
            return
        }

        print("Setting up grostat.\n")

        print("API token (from server.growatt.com): ", terminator: "")
        let token = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        print("Device serial number (e.g. NFB8922074): ", terminator: "")
        let deviceSn = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var config = Config()
        config.token = token
        config.deviceSn = deviceSn
        try Config.save(config)

        print("\nConfig saved: \(Config.configFile.path)")
        if token.isEmpty {
            print("Warning: token is empty. Set it with 'grostat token <value>'.")
        }
        if deviceSn.isEmpty {
            print("Warning: device SN is empty. Set it with 'grostat device <value>'.")
        }
        if !token.isEmpty && !deviceSn.isEmpty {
            print("Ready! Run 'grostat collect' to test, then 'grostat schedule' for automation.")
        }
    }
}
