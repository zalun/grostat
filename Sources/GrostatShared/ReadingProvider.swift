import Foundation

public protocol ReadingProvider {
    func readLatest() -> InverterReading?
    func readRange(from: Date, to: Date) -> [InverterReading]
    func readDailySummaries(from: Date, to: Date) -> [PeriodSummary]
}
