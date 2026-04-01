import ArgumentParser
import Foundation

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Show current configuration"
    )

    func run() throws {
        let config = Config.load()
        let maskedToken: String
        if config.token.isEmpty {
            maskedToken = "(not set)"
        } else {
            if config.token.count <= 10 {
                maskedToken = "***"
            } else {
                maskedToken = String(config.token.prefix(6)) + "..." + String(config.token.suffix(4))
            }
        }

        print("Config file:     \(Config.configFile.path)")
        print("token:           \(maskedToken)")
        print("device_sn:       \(config.deviceSn.isEmpty ? "(not set)" : config.deviceSn)")
        print("db_path:         \(config.dbPath)")
        print("api_base:        \(config.apiBase)")
        print("rated_power_w:   \(config.ratedPowerW)")
        print("alert_warning_v: \(config.alertWarningV)")
        print("alert_critical_v: \(config.alertCriticalV)")
        print("loop_interval_s: \(config.loopIntervalS)")
    }
}
