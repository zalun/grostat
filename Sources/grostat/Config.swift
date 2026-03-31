import Foundation

struct Config: Codable {
    var token: String = ""
    var deviceSn: String = "NFB8922074"
    var dbPath: String = "~/.local/share/grostat/grostat.db"
    var alertWarningV: Double = 250.0
    var alertCriticalV: Double = 253.0
    var apiBase: String = "https://openapi.growatt.com/v4/new-api"
    var loopIntervalS: Int = 300

    enum CodingKeys: String, CodingKey {
        case token
        case deviceSn = "device_sn"
        case dbPath = "db_path"
        case alertWarningV = "alert_warning_v"
        case alertCriticalV = "alert_critical_v"
        case apiBase = "api_base"
        case loopIntervalS = "loop_interval_s"
    }

    static let configDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/grostat")
    static let configFile = configDir.appendingPathComponent("config.json")

    static func load() -> Config {
        // Env vars override config file
        var config = loadFromFile()
        if let v = ProcessInfo.processInfo.environment["GROSTAT_TOKEN"] { config.token = v }
        if let v = ProcessInfo.processInfo.environment["GROSTAT_DEVICE_SN"] { config.deviceSn = v }
        if let v = ProcessInfo.processInfo.environment["GROSTAT_DB_PATH"] { config.dbPath = v }
        if let v = ProcessInfo.processInfo.environment["GROSTAT_ALERT_WARNING_V"],
           let d = Double(v) { config.alertWarningV = d }
        if let v = ProcessInfo.processInfo.environment["GROSTAT_ALERT_CRITICAL_V"],
           let d = Double(v) { config.alertCriticalV = d }
        if let v = ProcessInfo.processInfo.environment["GROSTAT_API_BASE"] { config.apiBase = v }
        if let v = ProcessInfo.processInfo.environment["GROSTAT_LOOP_INTERVAL_S"],
           let i = Int(v) { config.loopIntervalS = i }
        return config
    }

    var resolvedDbPath: String {
        let path = (dbPath as NSString).expandingTildeInPath
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        return path
    }

    private static func loadFromFile() -> Config {
        guard FileManager.default.fileExists(atPath: configFile.path),
              let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else {
            return Config()
        }
        return config
    }

    static func createDefault() throws -> URL {
        try FileManager.default.createDirectory(
            at: configDir, withIntermediateDirectories: true)
        let config = Config()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configFile)
        return configFile
    }
}
