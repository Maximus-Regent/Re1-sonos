import Foundation
import Network

/// Discovers Sonos devices on the local network using SSDP (Simple Service Discovery Protocol).
final class SSDPDiscovery: @unchecked Sendable {
    private let multicastGroup = "239.255.255.250"
    private let multicastPort: UInt16 = 1900
    private let searchTarget = "urn:schemas-upnp-org:device:ZonePlayer:1"

    private var connection: NWConnection?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.sonosClient.ssdp", qos: .userInitiated)

    typealias DiscoveryHandler = (String, Int) -> Void // ip, port
    private var onDeviceFound: DiscoveryHandler?

    deinit {
        stop()
    }

    /// Start searching for Sonos devices. Calls `handler` for each device found.
    func search(handler: @escaping DiscoveryHandler) {
        onDeviceFound = handler
        sendMSearch()
    }

    /// Stop listening.
    func stop() {
        connection?.cancel()
        listener?.cancel()
        connection = nil
        listener = nil
    }

    private func sendMSearch() {
        let message = [
            "M-SEARCH * HTTP/1.1",
            "HOST: \(multicastGroup):\(multicastPort)",
            "MAN: \"ssdp:discover\"",
            "MX: 3",
            "ST: \(searchTarget)",
            "",
            ""
        ].joined(separator: "\r\n")

        let host = NWEndpoint.Host(multicastGroup)
        let port = NWEndpoint.Port(integerLiteral: multicastPort)

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        connection = NWConnection(host: host, port: port, using: params)
        connection?.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.doSend(message)
                self?.receiveResponses()
            }
        }
        connection?.start(queue: queue)
    }

    private func doSend(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error {
                print("[SSDP] Send error: \(error)")
            }
        })
    }

    private func receiveResponses() {
        connection?.receiveMessage { [weak self] data, _, _, error in
            if let data, let response = String(data: data, encoding: .utf8) {
                self?.parseResponse(response)
            }
            if error == nil {
                self?.receiveResponses() // keep listening
            }
        }
    }

    private func parseResponse(_ response: String) {
        // Extract LOCATION header to get device description URL
        guard let locationLine = response.split(separator: "\r\n")
            .first(where: { $0.uppercased().hasPrefix("LOCATION:") }) else { return }

        let urlString = locationLine.dropFirst("LOCATION:".count).trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: urlString),
              let host = url.host,
              let port = url.port else { return }

        onDeviceFound?(host, port)
    }
}
