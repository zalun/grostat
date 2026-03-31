import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create config file at ~/.config/grostat/config.json"
    )

    func run() throws {
        if FileManager.default.fileExists(atPath: Config.configFile.path) {
            print("Config already exists: \(Config.configFile.path)")
            print("Edit it directly or delete it to recreate.")
            return
        }
        let path = try Config.createDefault()
        print("Created config: \(path.path)")
        print("Edit it and set your token before running 'grostat collect'.")
    }
}
