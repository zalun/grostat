import ArgumentParser
import Foundation

struct TokenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "token",
        abstract: "Set or show the Growatt API token"
    )

    @Argument(help: "API token to save (omit to show current)")
    var value: String?

    func run() throws {
        if let newToken = value {
            try Config.update { $0.token = newToken }
            print("Token saved to \(Config.configFile.path)")
        } else {
            let config = Config.load()
            if config.token.isEmpty {
                print("Token not set. Usage: grostat token <your-api-token>")
            } else {
                let masked = String(config.token.prefix(6)) + "..." + String(config.token.suffix(4))
                print(masked)
            }
        }
    }
}
