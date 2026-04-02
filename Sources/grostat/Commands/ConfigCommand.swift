import ArgumentParser
import Foundation

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Show or update configuration"
    )

    @Flag(name: .long, help: "Enable HTTP server in GrostatBar (server mode)")
    var server = false

    @Flag(name: .long, help: "Disable HTTP server in GrostatBar")
    var noServer = false

    @Flag(name: .long, help: "Switch GrostatBar to client mode (connect to a server)")
    var client = false

    @Flag(name: .long, help: "Switch GrostatBar to local mode (read from local DB)")
    var local = false

    @Option(name: .long, help: "Set server address for client mode (host:port)")
    var connectTo: String? = nil

    func run() throws {
        let hasChanges = server || noServer || client || local || connectTo != nil

        if hasChanges {
            try Config.update { config in
                if server { config.serverEnabled = true }
                if noServer { config.serverEnabled = false }
                if client { config.mode = "client" }
                if local { config.mode = "local" }
                if let addr = connectTo {
                    config.server = addr
                    config.mode = "client"
                }
            }
            print("Config updated. Restart GrostatBar to apply changes.")
        }

        let config = Config.load()
        let maskedToken: String
        if config.token.isEmpty {
            maskedToken = "(not set)"
        } else if config.token.count <= 10 {
            maskedToken = "***"
        } else {
            maskedToken = String(config.token.prefix(6)) + "..." + String(config.token.suffix(4))
        }

        print("Config file:      \(Config.configFile.path)")
        print("token:            \(maskedToken)")
        print("device_sn:        \(config.deviceSn.isEmpty ? "(not set)" : config.deviceSn)")
        print("db_path:          \(config.dbPath)")
        print("api_base:         \(config.apiBase)")
        print("rated_power_w:    \(config.ratedPowerW)")
        print("alert_warning_v:  \(config.alertWarningV)")
        print("alert_critical_v: \(config.alertCriticalV)")
        print("loop_interval_s:  \(config.loopIntervalS)")
        print("mode:             \(config.mode)")
        print("server_enabled:   \(config.serverEnabled)")
        print("server_port:      \(config.serverPort)")
        if let srv = config.server {
            print("server:           \(srv)")
        }
    }
}
