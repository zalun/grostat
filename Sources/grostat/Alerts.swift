import Foundation
import GrostatShared

struct AlertChecker {
    let ratedPowerW: Int
    let criticalV: Double
    let criticalClearV: Double
    private let stateFile: String

    init(config: Config) {
        self.ratedPowerW = config.ratedPowerW
        self.criticalV = config.alertCriticalV
        self.criticalClearV = config.alertCriticalV - 2  // 253 → 251 hysteresis
        let dir = (config.resolvedDbPath as NSString).deletingLastPathComponent
        self.stateFile = "\(dir)/alert_state.json"
    }

    func evaluate(_ reading: InverterReading) -> String {
        let previous = readState()
        var current = previous

        // Production state
        let prodState = productionState(reading)
        if prodState != previous.productionState {
            current.productionState = prodState
            let (title, message) = productionNotification(prodState, reading)
            notify(title: title, message: message)
        }

        // Voltage with hysteresis
        let v = reading.vmaxPhase
        if !previous.voltageCritical && v >= criticalV {
            current.voltageCritical = true
            notify(
                title: "grostat CRITICAL",
                message: "\(f1(v))V — grid voltage exceeded \(f1(criticalV))V!",
                subtitle: "R:\(f1(reading.vacrPhase))V S:\(f1(reading.vacsPhase))V T:\(f1(reading.vactPhase))V"
            )
        } else if previous.voltageCritical && v < criticalClearV {
            current.voltageCritical = false
            notify(
                title: "grostat OK",
                message: "Voltage back to normal: \(f1(v))V",
                subtitle: "R:\(f1(reading.vacrPhase))V S:\(f1(reading.vacsPhase))V T:\(f1(reading.vactPhase))V"
            )
        }

        if current != previous {
            writeState(current)
        }

        // Return alert level for DB column
        if current.voltageCritical { return "CRITICAL" }
        if prodState == "fault" { return "FAULT" }
        return ""
    }

    // MARK: - Production state (mirrors GrostatBar InverterState)

    private func productionState(_ r: InverterReading) -> String {
        if r.isOffline { return "offline" }
        if r.status == 3 { return "fault" }
        if r.status == 0 || r.ppv == 0 { return "sleep" }
        let onFireThreshold = Double(ratedPowerW) * 0.7
        if r.ppv >= onFireThreshold { return "onFire" }
        let cloudyThreshold = Double(ratedPowerW) * 0.4
        if r.ppv < cloudyThreshold { return "cloudy" }
        return "producing"
    }

    private func productionNotification(_ state: String, _ r: InverterReading) -> (title: String, message: String) {
        let kw = String(format: "%.1f", r.ppv / 1000.0)
        switch state {
        case "sleep":
            return ("grostat", "Inverter sleeping")
        case "cloudy":
            return ("grostat", "Low production: \(kw) kW")
        case "producing":
            return ("grostat", "Producing: \(kw) kW")
        case "onFire":
            return ("grostat", "Full power: \(kw) kW")
        case "fault":
            return ("grostat FAULT", "Inverter fault (type \(r.faultType))")
        case "offline":
            return ("grostat", "Inverter offline")
        default:
            return ("grostat", "State: \(state)")
        }
    }

    // MARK: - State persistence

    private struct AlertState: Codable, Equatable {
        var productionState: String = ""
        var voltageCritical: Bool = false
    }

    private func readState() -> AlertState {
        guard let data = FileManager.default.contents(atPath: stateFile),
              let state = try? JSONDecoder().decode(AlertState.self, from: data)
        else { return AlertState() }
        return state
    }

    private func writeState(_ state: AlertState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: URL(fileURLWithPath: stateFile))
    }

    // MARK: - Notifications

    private func notify(title: String, message: String, subtitle: String = "") {
        #if os(macOS)
            var script = "display notification \"\(message)\" with title \"\(title)\""
            if !subtitle.isEmpty {
                script += " subtitle \"\(subtitle)\""
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        #endif
    }

    private func f1(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
}
