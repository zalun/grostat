import Foundation

struct AlertChecker {
    let warningV: Double
    let criticalV: Double

    init(config: Config) {
        self.warningV = config.alertWarningV
        self.criticalV = config.alertCriticalV
    }

    func evaluate(_ reading: InverterReading) -> String {
        let v = reading.vmaxPhase

        if v >= criticalV {
            Log.critical(
                "CRITICAL: vmax_phase=\(f1(v))V (>= \(f1(criticalV))V) "
                    + "phases R:\(f1(reading.vacrPhase)) S:\(f1(reading.vacsPhase)) T:\(f1(reading.vactPhase))"
            )
            notify(
                title: "grostat CRITICAL",
                message: "CRITICAL: \(f1(v))V (grid voltage exceeded!)",
                subtitle:
                    "R:\(f1(reading.vacrPhase))V S:\(f1(reading.vacsPhase))V T:\(f1(reading.vactPhase))V"
            )
            return "CRITICAL"
        } else if v >= warningV {
            Log.warning(
                "WARNING: vmax_phase=\(f1(v))V (>= \(f1(warningV))V) "
                    + "phases R:\(f1(reading.vacrPhase)) S:\(f1(reading.vacsPhase)) T:\(f1(reading.vactPhase))"
            )
            notify(
                title: "grostat",
                message: "WARNING: \(f1(v))V (approaching grid limit)",
                subtitle:
                    "R:\(f1(reading.vacrPhase))V S:\(f1(reading.vacsPhase))V T:\(f1(reading.vactPhase))V"
            )
            return "WARNING"
        }

        return ""
    }

    private func notify(title: String, message: String, subtitle: String) {
        #if os(macOS)
            let script =
                "display notification \"\(message)\" with title \"\(title)\" subtitle \"\(subtitle)\""
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
