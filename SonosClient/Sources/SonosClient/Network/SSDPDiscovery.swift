import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Discovers Sonos devices on the local network using SSDP (Simple Service Discovery Protocol).
///
/// Uses raw BSD UDP sockets for proper multicast send/receive, which is more
/// reliable than NWConnection for SSDP M-SEARCH discovery. Sends multiple
/// search bursts and listens for unicast responses.
final class SSDPDiscovery: @unchecked Sendable {
    private let multicastGroup = "239.255.255.250"
    private let multicastPort: UInt16 = 1900
    private let searchTarget = "urn:schemas-upnp-org:device:ZonePlayer:1"

    private var socketFD: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.sonosClient.ssdp", qos: .userInitiated)

    typealias DiscoveryHandler = (String, Int) -> Void
    private var onDeviceFound: DiscoveryHandler?

    deinit {
        stop()
    }

    /// Start searching for Sonos devices. Calls `handler` for each unique device found.
    func search(handler: @escaping DiscoveryHandler) {
        stop() // clean up any previous search
        onDeviceFound = handler
        isRunning = true

        queue.async { [weak self] in
            self?.performSearch()
        }
    }

    /// Stop listening and close the socket.
    func stop() {
        isRunning = false
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
    }

    // MARK: - BSD Socket Implementation

    private func performSearch() {
        // Create UDP socket
        socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            print("[SSDP] Failed to create socket: \(String(cString: strerror(errno)))")
            return
        }

        // Allow address reuse
        var reuse: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))

        // Set receive timeout (2 seconds per read attempt)
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Bind to any address on an ephemeral port
        var bindAddr = sockaddr_in()
        bindAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = 0 // ephemeral
        bindAddr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &bindAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(socketFD, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bindResult < 0 {
            print("[SSDP] Bind failed: \(String(cString: strerror(errno)))")
            close(socketFD)
            socketFD = -1
            return
        }

        // Build the M-SEARCH message
        let message = [
            "M-SEARCH * HTTP/1.1",
            "HOST: \(multicastGroup):\(multicastPort)",
            "MAN: \"ssdp:discover\"",
            "MX: 3",
            "ST: \(searchTarget)",
            "USER-AGENT: SonosClient/1.0 macOS UPnP/1.1",
            "",
            ""
        ].joined(separator: "\r\n")

        guard let messageData = message.data(using: .utf8) else {
            close(socketFD)
            socketFD = -1
            return
        }

        // Build multicast destination address
        var destAddr = sockaddr_in()
        destAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destAddr.sin_family = sa_family_t(AF_INET)
        destAddr.sin_port = multicastPort.bigEndian
        inet_pton(AF_INET, multicastGroup, &destAddr.sin_addr)

        // Send multiple M-SEARCH bursts for reliability (UDP is lossy)
        for burst in 0..<3 {
            guard isRunning else { break }

            messageData.withUnsafeBytes { rawBuf in
                guard let baseAddress = rawBuf.baseAddress else { return }
                withUnsafePointer(to: &destAddr) { addrPtr in
                    addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                        let sent = sendto(
                            socketFD, baseAddress, messageData.count, 0,
                            sockAddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size)
                        )
                        if sent < 0 {
                            print("[SSDP] Send failed (burst \(burst)): \(String(cString: strerror(errno)))")
                        } else {
                            print("[SSDP] M-SEARCH sent (burst \(burst + 1)/3, \(sent) bytes)")
                        }
                    }
                }
            }

            // Listen for responses between bursts
            listenForResponses(duration: 3.0)
        }

        // Final listen period
        if isRunning {
            listenForResponses(duration: 4.0)
        }

        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
    }

    private func listenForResponses(duration: TimeInterval) {
        let deadline = Date().addingTimeInterval(duration)
        var buffer = [UInt8](repeating: 0, count: 4096)
        var senderAddr = sockaddr_in()
        var senderAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        while isRunning && Date() < deadline {
            let bytesRead = withUnsafeMutablePointer(to: &senderAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                    recvfrom(socketFD, &buffer, buffer.count, 0, sockAddrPtr, &senderAddrLen)
                }
            }

            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                if let response = String(data: data, encoding: .utf8) {
                    parseResponse(response)
                }
            }
            // On timeout (bytesRead < 0 with EAGAIN/EWOULDBLOCK), just loop
        }
    }

    private func parseResponse(_ response: String) {
        // Only process responses that look like Sonos / ZonePlayer
        let upper = response.uppercased()
        guard upper.contains("ZONEPLAYER") || upper.contains("SONOS") || upper.contains("LOCATION:") else {
            return
        }

        // Extract LOCATION header
        guard let locationLine = response.split(separator: "\r\n")
            .first(where: { $0.uppercased().hasPrefix("LOCATION:") }) else { return }

        let urlString = String(locationLine.dropFirst("LOCATION:".count)).trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: urlString),
              let host = url.host else { return }

        let port = url.port ?? 1400

        print("[SSDP] Found device at \(host):\(port)")
        onDeviceFound?(host, port)
    }
}
