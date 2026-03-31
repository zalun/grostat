import ArgumentParser
import Foundation

struct CollectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "collect",
        abstract: "Fetch one reading from the inverter and store it"
    )

    @Flag(name: .long, help: "Continuous collection mode")
    var loop = false

    func run() throws {
        let config = Config.load()
        guard !config.token.isEmpty else {
            print("Token not set. Run 'grostat init' and edit config, or set GROSTAT_TOKEN.")
            throw ExitCode.failure
        }
        guard !config.deviceSn.isEmpty else {
            print("Device SN not set. Edit ~/.config/grostat/config.json or set GROSTAT_DEVICE_SN.")
            throw ExitCode.failure
        }

        let dbPath = config.resolvedDbPath
        Log.setupFileLog(dbPath: dbPath)
        let db = try Database(path: dbPath)
        let client = GrowattClient(config: config)
        let alerts = AlertChecker(config: config)

        if !loop {
            try collectOnce(client: client, db: db, alerts: alerts)
            return
        }

        Log.info("Starting continuous collection (every \(config.loopIntervalS)s). Ctrl+C to stop.")
        signal(SIGINT) { _ in
            Log.info("Stopped by user.")
            Foundation.exit(0)
        }

        while true {
            _ = try? collectOnce(client: client, db: db, alerts: alerts)
            Thread.sleep(forTimeInterval: Double(config.loopIntervalS))
        }
    }

    @discardableResult
    private func collectOnce(
        client: GrowattClient, db: Database, alerts: AlertChecker
    ) throws -> Bool {
        var reading: InverterReading
        do {
            reading = try client.fetchLastData()
        } catch {
            Log.error("Failed to fetch data: \(error)")
            return false
        }

        let level = alerts.evaluate(reading)
        reading.alert = level
        db.insertReading(reading)

        let statusTxt: String
        switch reading.status {
        case 0: statusTxt = "WAIT"
        case 1: statusTxt = "OK"
        case 3: statusTxt = "FAULT"
        default: statusTxt = "?\(reading.status)"
        }

        let suffix = level.isEmpty ? "" : " [\(level)]"
        Log.info(
            "\(statusTxt) | "
                + "R:\(f1(reading.vacrPhase))V S:\(f1(reading.vacsPhase))V T:\(f1(reading.vactPhase))V "
                + "(max=\(f1(reading.vmaxPhase))V) | "
                + "PAC=\(f1(reading.pac))W | DC=\(f1(reading.ppv))W | "
                + "E=\(f1(reading.powerToday))kWh\(suffix)")
        return true
    }

    private func f1(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
}
