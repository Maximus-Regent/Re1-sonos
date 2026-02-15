import Foundation

/// Discovers Sonos devices on the local network using SSDP (Simple Service Discovery Protocol).
final class SSDPDiscovery: @unchecked Sendable {
    private let multicastGroup = "239.255.255.250"
    private let multicastPort: UInt16 = 1900
    private let searchTarget = "urn:schemas-upnp-org:device:ZonePlayer:1"

    private let queue = DispatchQueue(label: "com.sonosClient.ssdp", qos: .userInitiated)
    private var socket: Int32 = -1
    private var isRunning = false

    typealias DiscoveryHandler = (String, Int) -> Void // ip, port
    private var onDeviceFound: DiscoveryHandler?

    deinit {
        stop()
    }

    /// Start searching for Sonos devices. Calls `handler` for each device found.
    func search(handler: @escaping DiscoveryHandler) {
        onDeviceFound = handler
        queue.async { [weak self] in
            self?.performSearch()
        }
    }

    /// Stop listening.
    func stop() {
        isRunning = false
        let sock = socket
        socket = -1
        if sock >= 0 {
            // Shutdown the socket to unblock any recv() call on the background queue
            Darwin.shutdown(sock, SHUT_RDWR)
            close(sock)
        }
    }

    private func performSearch() {
        // Create UDP socket
        socket = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socket >= 0 else {
            print("[SSDP] Failed to create socket")
            return
        }

        // Allow address reuse
        var reuse: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(socket, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))

        // Set receive timeout to 4 seconds
        var timeout = timeval(tv_sec: 4, tv_usec: 0)
        setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Build M-SEARCH message
        let message = [
            "M-SEARCH * HTTP/1.1",
            "HOST: \(multicastGroup):\(multicastPort)",
            "MAN: \"ssdp:discover\"",
            "MX: 3",
            "ST: \(searchTarget)",
            "",
            ""
        ].joined(separator: "\r\n")

        // Set up multicast destination address
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = multicastPort.bigEndian
        inet_pton(AF_INET, multicastGroup, &addr.sin_addr)

        // Send M-SEARCH
        let messageData = Array(message.utf8)
        let sent = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                sendto(socket, messageData, messageData.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if sent < 0 {
            print("[SSDP] Send failed: \(String(cString: strerror(errno)))")
            close(socket)
            socket = -1
            return
        }

        // Receive responses
        isRunning = true
        var buffer = [UInt8](repeating: 0, count: 4096)

        while isRunning {
            let sock = socket
            guard sock >= 0 else { break }
            let bytesRead = recv(sock, &buffer, buffer.count, 0)
            if bytesRead <= 0 { break }

            if let response = String(bytes: buffer[..<bytesRead], encoding: .utf8) {
                parseResponse(response)
            }
        }

        let sock = socket
        socket = -1
        if sock >= 0 {
            close(sock)
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
