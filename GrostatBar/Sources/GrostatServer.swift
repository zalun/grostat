import Foundation
import GrostatShared
import Network
import os

private let log = Logger(subsystem: "com.grostat.bar", category: "GrostatServer")

final class GrostatServer {
    private let reader: StatusReader
    private let config: BarConfig
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.grostat.server")

    init(reader: StatusReader, config: BarConfig) {
        self.reader = reader
        self.config = config
    }

    func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: UInt16(config.serverPort)))
        } catch {
            log.error("Failed to create listener: \(error.localizedDescription)")
            return
        }

        // Bonjour advertisement
        let txtRecord = NWTXTRecord([
            "device_sn": config.deviceSn,
            "version": "1",
        ])
        listener?.service = NWListener.Service(name: config.deviceSn, type: "_grostat._tcp", txtRecord: txtRecord)

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                log.info("Server listening on port \(self.config.serverPort)")
            case .failed(let error):
                log.error("Server failed: \(error.localizedDescription)")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }
            let request = String(data: data, encoding: .utf8) ?? ""
            let response = self.route(request)
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    // MARK: - Routing

    private func route(_ request: String) -> String {
        guard let firstLine = request.split(separator: "\r\n").first else {
            return httpResponse(status: 400, body: #"{"error":"Bad Request"}"#)
        }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            return httpResponse(status: 405, body: #"{"error":"Method Not Allowed"}"#)
        }

        let fullPath = String(parts[1])
        let (path, query) = parseURL(fullPath)

        switch path {
        case "/status":
            return handleStatus()
        case "/readings":
            return handleReadings(query: query)
        case "/config":
            return handleConfig()
        default:
            return httpResponse(status: 404, body: #"{"error":"Not Found"}"#)
        }
    }

    // MARK: - Handlers

    private func handleStatus() -> String {
        guard let reading = reader.readLatest() else {
            return httpResponse(status: 204, body: "")
        }
        guard let json = encodeJSON(reading) else {
            return httpResponse(status: 500, body: #"{"error":"Encoding failed"}"#)
        }
        return httpResponse(status: 200, body: json)
    }

    private func handleReadings(query: [String: String]) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        let from: Date
        let to: Date

        if let dateStr = query["date"], let d = fmt.date(from: dateStr) {
            from = d
            to = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d
        } else if let fromStr = query["from"], let toStr = query["to"],
                  let f = fmt.date(from: fromStr), let t = fmt.date(from: toStr) {
            from = f
            to = Calendar.current.date(byAdding: .day, value: 1, to: t) ?? t
        } else {
            return httpResponse(status: 400, body: #"{"error":"Missing date or from/to parameters"}"#)
        }

        let readings = reader.readRange(from: from, to: to)
        guard let json = encodeJSON(readings) else {
            return httpResponse(status: 500, body: #"{"error":"Encoding failed"}"#)
        }
        return httpResponse(status: 200, body: json)
    }

    private func handleConfig() -> String {
        let configData: [String: Any] = [
            "device_sn": config.deviceSn,
            "rated_power_w": config.ratedPowerW,
            "alert_warning_v": config.alertWarningV,
            "alert_critical_v": config.alertCriticalV,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: configData),
              let json = String(data: data, encoding: .utf8) else {
            return httpResponse(status: 500, body: #"{"error":"Encoding failed"}"#)
        }
        return httpResponse(status: 200, body: json)
    }

    // MARK: - HTTP helpers

    private func httpResponse(status: Int, body: String) -> String {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 204: statusText = "No Content"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        if status == 204 {
            return "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n"
        }

        let contentType = "application/json"
        let bodyData = body.data(using: .utf8) ?? Data()
        return "HTTP/1.1 \(status) \(statusText)\r\n"
            + "Content-Type: \(contentType)\r\n"
            + "Content-Length: \(bodyData.count)\r\n"
            + "Connection: close\r\n"
            + "\r\n"
            + body
    }

    private func parseURL(_ url: String) -> (path: String, query: [String: String]) {
        let parts = url.split(separator: "?", maxSplits: 1)
        let path = String(parts[0])
        var query: [String: String] = [:]
        if parts.count > 1 {
            for param in parts[1].split(separator: "&") {
                let kv = param.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    query[String(kv[0])] = String(kv[1])
                }
            }
        }
        return (path, query)
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()

    private func encodeJSON<T: Encodable>(_ value: T) -> String? {
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
