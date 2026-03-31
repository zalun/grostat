import AppKit

enum InverterState {
    case sleep
    case cloudy      // < 40% rated power
    case producing   // 40%–70% rated power
    case onFire      // ≥ 70% rated power
    case fault
    case offline

    var sfSymbolName: String {
        switch self {
        case .sleep: return "moon.zzz"
        case .cloudy: return "cloud.fill"
        case .producing: return "sun.max.fill"
        case .onFire: return "bolt.fill"
        case .fault: return "exclamationmark.triangle.fill"
        case .offline: return "questionmark.circle"
        }
    }

    static func from(reading: InverterReading?, config: BarConfig) -> InverterState {
        guard let r = reading else { return .offline }
        if r.isStale { return .offline }
        if r.status == 3 { return .fault }
        if r.status == 0 || r.ppv == 0 { return .sleep }
        if r.ppv >= config.onFireThreshold { return .onFire }
        let cloudyThreshold = Double(config.ratedPowerW) * 0.4
        if r.ppv < cloudyThreshold { return .cloudy }
        return .producing
    }
}

enum VoltageLevel {
    case normal
    case warning
    case critical

    var color: NSColor {
        switch self {
        case .normal: return .systemGreen
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }

    static func from(vmaxPhase: Double, config: BarConfig) -> VoltageLevel {
        if vmaxPhase >= config.alertCriticalV { return .critical }
        if vmaxPhase >= config.alertWarningV { return .warning }
        return .normal
    }
}
