import Foundation

enum AppMode: String, Codable {
    case local
    case client
}

struct BarConfig: Codable {
    var deviceSn: String = ""
    var dbPath: String = "~/.local/share/grostat/grostat.db"
    var alertWarningV: Double = 250.0
    var alertCriticalV: Double = 253.0
    var ratedPowerW: Int = 10000
    var mode: AppMode = .local
    var serverEnabled: Bool = false
    var serverPort: Int = 7654
    var server: String? = nil

    enum CodingKeys: String, CodingKey {
        case deviceSn = "device_sn"
        case dbPath = "db_path"
        case alertWarningV = "alert_warning_v"
        case alertCriticalV = "alert_critical_v"
        case ratedPowerW = "rated_power_w"
        case mode
        case serverEnabled = "server_enabled"
        case serverPort = "server_port"
        case server
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deviceSn = (try? c.decode(String.self, forKey: .deviceSn)) ?? ""
        dbPath = (try? c.decode(String.self, forKey: .dbPath)) ?? "~/.local/share/grostat/grostat.db"
        alertWarningV = (try? c.decode(Double.self, forKey: .alertWarningV)) ?? 250.0
        alertCriticalV = (try? c.decode(Double.self, forKey: .alertCriticalV)) ?? 253.0
        ratedPowerW = (try? c.decode(Int.self, forKey: .ratedPowerW)) ?? 10000
        mode = (try? c.decode(AppMode.self, forKey: .mode)) ?? .local
        serverEnabled = (try? c.decode(Bool.self, forKey: .serverEnabled)) ?? false
        serverPort = (try? c.decode(Int.self, forKey: .serverPort)) ?? 7654
        server = try? c.decode(String.self, forKey: .server)
    }

    var resolvedDbPath: String {
        (dbPath as NSString).expandingTildeInPath
    }

    var onFireThreshold: Double {
        Double(ratedPowerW) * 0.7
    }

    static func load() -> BarConfig {
        let configFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/grostat/config.json")
        guard FileManager.default.fileExists(atPath: configFile.path),
              let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(BarConfig.self, from: data)
        else {
            return BarConfig()
        }
        return config
    }

    static var configFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/grostat/config.json")
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        let dir = Self.configFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: Self.configFileURL)
    }
}
