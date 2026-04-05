import Foundation

public struct PeriodSummary: Codable {
    public let periodStart: String
    public let totalEnergy: Double
    public let peakPowerAC: Double
    public let peakPowerDC: Double
    public let peakVoltage: Double
    public let maxTemperature: Double
    public let peakPpv1: Double
    public let peakPpv2: Double

    public init(
        periodStart: String,
        totalEnergy: Double,
        peakPowerAC: Double,
        peakPowerDC: Double,
        peakVoltage: Double,
        maxTemperature: Double,
        peakPpv1: Double,
        peakPpv2: Double
    ) {
        self.periodStart = periodStart
        self.totalEnergy = totalEnergy
        self.peakPowerAC = peakPowerAC
        self.peakPowerDC = peakPowerDC
        self.peakVoltage = peakVoltage
        self.maxTemperature = maxTemperature
        self.peakPpv1 = peakPpv1
        self.peakPpv2 = peakPpv2
    }

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public var date: Date? {
        Self.dateParser.date(from: periodStart)
    }
}
