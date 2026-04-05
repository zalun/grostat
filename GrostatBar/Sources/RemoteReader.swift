import Foundation
import GrostatShared
import os

private let log = Logger(subsystem: "com.grostat.bar", category: "RemoteReader")

struct RemoteConfig {
    let deviceSn: String
    let ratedPowerW: Int
    let alertWarningV: Double
    let alertCriticalV: Double
}

final class RemoteReader: ReadingProvider {
    let host: String
    let port: UInt16
    private(set) var remoteConfig: RemoteConfig?
    private var failCount = 0
    var onConnectionFailed: (() -> Void)?

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    private let decoder = JSONDecoder()

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    func fetchConfig() {
        guard let url = URL(string: "http://\(host):\(port)/config") else { return }
        let sem = DispatchSemaphore(value: 0)
        session.dataTask(with: url) { [weak self] data, _, _ in
            defer { sem.signal() }
            guard let self, let data else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.remoteConfig = RemoteConfig(
                    deviceSn: json["device_sn"] as? String ?? "",
                    ratedPowerW: json["rated_power_w"] as? Int ?? 10000,
                    alertWarningV: json["alert_warning_v"] as? Double ?? 250.0,
                    alertCriticalV: json["alert_critical_v"] as? Double ?? 253.0
                )
                self.failCount = 0
            }
        }.resume()
        sem.wait()
    }

    func readLatest() -> InverterReading? {
        guard let url = URL(string: "http://\(host):\(port)/status") else { return nil }
        var result: InverterReading?
        let sem = DispatchSemaphore(value: 0)

        session.dataTask(with: url) { [weak self] data, response, error in
            defer { sem.signal() }
            guard let self else { return }
            if let error {
                log.error("Failed to fetch status: \(error.localizedDescription)")
                self.handleFailure()
                return
            }
            guard let http = response as? HTTPURLResponse else { return }
            if http.statusCode == 204 { return }
            guard http.statusCode == 200, let data else { return }
            result = try? self.decoder.decode(InverterReading.self, from: data)
            self.failCount = 0
        }.resume()
        sem.wait()
        return result
    }

    func readRange(from: Date, to: Date) -> [InverterReading] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let fromStr = fmt.string(from: from)
        let toStr = fmt.string(from: to)

        guard let url = URL(string: "http://\(host):\(port)/readings?from=\(fromStr)&to=\(toStr)")
        else { return [] }
        var result: [InverterReading] = []
        let sem = DispatchSemaphore(value: 0)

        session.dataTask(with: url) { [weak self] data, response, error in
            defer { sem.signal() }
            guard let self else { return }
            if let error {
                log.error("Failed to fetch readings: \(error.localizedDescription)")
                self.handleFailure()
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data else {
                return
            }
            result = (try? self.decoder.decode([InverterReading].self, from: data)) ?? []
            self.failCount = 0
        }.resume()
        sem.wait()
        return result
    }

    func readDailySummaries(from: Date, to: Date) -> [PeriodSummary] {
        return fetchSummaries(endpoint: "summary/daily", from: from, to: to)
    }

    func fetchSummaries(endpoint: String, from: Date, to: Date) -> [PeriodSummary] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let fromStr = fmt.string(from: from)
        let toStr = fmt.string(from: to)

        guard
            let url = URL(string: "http://\(host):\(port)/\(endpoint)?from=\(fromStr)&to=\(toStr)")
        else { return [] }
        var result: [PeriodSummary] = []
        let sem = DispatchSemaphore(value: 0)

        session.dataTask(with: url) { [weak self] data, response, error in
            defer { sem.signal() }
            guard let self else { return }
            if let error {
                log.error("Failed to fetch summaries: \(error.localizedDescription)")
                self.handleFailure()
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data else {
                return
            }
            do {
                result = try self.decoder.decode([PeriodSummary].self, from: data)
            } catch {
                log.error("Failed to decode summaries: \(error)")
            }
            self.failCount = 0
        }.resume()
        sem.wait()
        return result
    }

    private func handleFailure() {
        failCount += 1
        if failCount >= 3 {
            log.warning("Server unreachable after \(self.failCount) attempts, triggering fallback")
            DispatchQueue.main.async { [weak self] in
                self?.onConnectionFailed?()
            }
        }
    }
}
