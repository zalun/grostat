import Foundation

struct BarConfig: Codable {
    var deviceSn: String = ""
    var dbPath: String = "~/.local/share/grostat/grostat.db"
    var alertWarningV: Double = 250.0
    var alertCriticalV: Double = 253.0
    var ratedPowerW: Int = 10000

    enum CodingKeys: String, CodingKey {
        case deviceSn = "device_sn"
        case dbPath = "db_path"
        case alertWarningV = "alert_warning_v"
        case alertCriticalV = "alert_critical_v"
        case ratedPowerW = "rated_power_w"
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
}
