import Foundation

public protocol ReadingProvider {
    func readLatest() -> InverterReading?
    func readRange(from: Date, to: Date) -> [InverterReading]
}
