import Foundation

struct Config: Codable {
    var token: String = ""
    var deviceSn: String = ""
    var dbPath: String = "~/.local/share/grostat/grostat.db"
    var alertWarningV: Double = 250.0
    var alertCriticalV: Double = 253.0
    var apiBase: String = "https://openapi.growatt.com/v4/new-api"
    var loopIntervalS: Int = 300
    var ratedPowerW: Int = 10000
    var mode: String = "local"
    var serverEnabled: Bool = false
    var serverPort: Int = 7654
    var server: String? = nil

    enum CodingKeys: String, CodingKey {
        case token
        case deviceSn = "device_sn"
        case dbPath = "db_path"
        case alertWarningV = "alert_warning_v"
        case alertCriticalV = "alert_critical_v"
        case apiBase = "api_base"
        case loopIntervalS = "loop_interval_s"
        case ratedPowerW = "rated_power_w"
        case mode
        case serverEnabled = "server_enabled"
        case serverPort = "server_port"
        case server
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = (try? c.decode(String.self, forKey: .token)) ?? ""
        deviceSn = (try? c.decode(String.self, forKey: .deviceSn)) ?? ""
        dbPath = (try? c.decode(String.self, forKey: .dbPath)) ?? "~/.local/share/grostat/grostat.db"
        alertWarningV = (try? c.decode(Double.self, forKey: .alertWarningV)) ?? 250.0
        alertCriticalV = (try? c.decode(Double.self, forKey: .alertCriticalV)) ?? 253.0
        apiBase = (try? c.decode(String.self, forKey: .apiBase)) ?? "https://openapi.growatt.com/v4/new-api"
        loopIntervalS = (try? c.decode(Int.self, forKey: .loopIntervalS)) ?? 300
        ratedPowerW = (try? c.decode(Int.self, forKey: .ratedPowerW)) ?? 10000
        mode = (try? c.decode(String.self, forKey: .mode)) ?? "local"
        serverEnabled = (try? c.decode(Bool.self, forKey: .serverEnabled)) ?? false
        serverPort = (try? c.decode(Int.self, forKey: .serverPort)) ?? 7654
        server = try? c.decode(String.self, forKey: .server)
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
        if let v = ProcessInfo.processInfo.environment["GROSTAT_RATED_POWER_W"],
           let i = Int(v) { config.ratedPowerW = i }
        return config
    }

    var resolvedDbPath: String {
        (dbPath as NSString).expandingTildeInPath
    }

    func ensureDbDirectory() {
        let dir = (resolvedDbPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
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
        try save(config)
        return configFile
    }

    static func save(_ config: Config) throws {
        try FileManager.default.createDirectory(
            at: configDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configFile)
    }

    /// Load config from file only (no env overrides), modify, and save back.
    static func update(_ modify: (inout Config) -> Void) throws {
        var config = loadFromFile()
        modify(&config)
        try save(config)
    }
}
