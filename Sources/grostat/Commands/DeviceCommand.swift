import ArgumentParser
import Foundation

struct DeviceCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "device",
        abstract: "Set or show the device serial number"
    )

    @Argument(help: "Device serial number to save (omit to show current)")
    var value: String?

    func run() throws {
        if let newSn = value {
            try Config.update { $0.deviceSn = newSn }
            print("Device SN saved: \(newSn)")
        } else {
            let config = Config.load()
            if config.deviceSn.isEmpty {
                print("Device SN not set. Usage: grostat device <serial-number>")
            } else {
                print(config.deviceSn)
            }
        }
    }
}
