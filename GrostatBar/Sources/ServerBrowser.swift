import Foundation
import Network
import os

private let log = Logger(subsystem: "com.grostat.bar", category: "ServerBrowser")

struct DiscoveredServer: Identifiable, Hashable {
    let id: String  // endpoint description
    let deviceSn: String
    let hostname: String
    let port: UInt16

    var address: String {
        "\(hostname):\(port)"
    }
}

final class ServerBrowser {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.grostat.browser")
    var onUpdate: (([DiscoveredServer]) -> Void)?

    private var discovered: [NWBrowser.Result] = []

    func start() {
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: "_grostat._tcp", domain: nil), using: params)

        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                log.info("Browser ready, scanning for servers...")
            case .failed(let error):
                log.error("Browser failed: \(error.localizedDescription)")
            default:
                break
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            self.discovered = Array(results)
            let servers = self.discovered.compactMap { self.toDiscoveredServer($0) }
            DispatchQueue.main.async {
                self.onUpdate?(servers)
            }
        }

        browser?.start(queue: queue)
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    private func toDiscoveredServer(_ result: NWBrowser.Result) -> DiscoveredServer? {
        guard case .service(let name, let type, let domain, _) = result.endpoint else { return nil }

        var deviceSn = ""
        let port: UInt16 = 7654

        if case .bonjour(let record) = result.metadata {
            if let sn = record["device_sn"] { deviceSn = sn }
        }

        return DiscoveredServer(
            id: "\(name).\(type).\(domain)",
            deviceSn: deviceSn,
            hostname: name,
            port: port
        )
    }

    func resolve(_ server: DiscoveredServer, completion: @escaping (String, UInt16) -> Void) {
        guard
            let result = discovered.first(where: {
                if case .service(let name, _, _, _) = $0.endpoint {
                    return "\(name)" == server.hostname
                }
                return false
            })
        else { return }

        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                if let path = connection.currentPath,
                    let endpoint = path.remoteEndpoint,
                    case .hostPort(let host, let port) = endpoint
                {
                    completion(Self.urlHost(from: host), port.rawValue)
                }
                connection.cancel()
            }
        }
        connection.start(queue: self.queue)
    }

    /// Convert NWEndpoint.Host into a URL-safe host string.
    /// IPv4: dotted form, scope ID dropped (URLs don't accept it and it's not needed).
    /// IPv6: bracketed, scope ID URL-encoded (% → %25) so URL(string:) parses link-local.
    static func urlHost(from host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let addr):
            // IPv4Address description may include "%interface" — strip it.
            let raw = "\(addr)"
            return raw.split(separator: "%").first.map(String.init) ?? raw
        case .ipv6(let addr):
            let encoded = "\(addr)".replacingOccurrences(of: "%", with: "%25")
            return "[\(encoded)]"
        case .name(let name, _):
            return name
        @unknown default:
            return "\(host)"
        }
    }
}
