import Foundation
import Network

/// Fallback discovery method: scans the local subnet for Sonos devices by probing
/// port 1400 (the default Sonos HTTP port) on each IP address.
///
/// Used when SSDP multicast discovery fails (e.g. due to network/firewall config).
final class SubnetScanner: @unchecked Sendable {

    typealias ScanHandler = (String, Int) -> Void

    /// Scan the local /24 subnet for Sonos devices.
    func scan(handler: @escaping ScanHandler) async {
        guard let localIP = getLocalIPAddress() else {
            print("[SubnetScan] Could not determine local IP address")
            return
        }

        let prefix = subnetPrefix(from: localIP)
        print("[SubnetScan] Scanning \(prefix).1-254 on port 1400...")

        // Scan in parallel batches to avoid overwhelming the network
        let batchSize = 32
        for batchStart in stride(from: 1, to: 255, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, 255)
            await withTaskGroup(of: (String, Bool).self) { group in
                for i in batchStart..<batchEnd {
                    let ip = "\(prefix).\(i)"
                    group.addTask {
                        let reachable = await self.probeSonosPort(ip: ip)
                        return (ip, reachable)
                    }
                }
                for await (ip, reachable) in group {
                    if reachable {
                        print("[SubnetScan] Found Sonos at \(ip)")
                        handler(ip, 1400)
                    }
                }
            }
        }
    }

    /// Try to connect to port 1400 and check if it responds like a Sonos device.
    private func probeSonosPort(ip: String) async -> Bool {
        do {
            let url = URL(string: "http://\(ip):1400/xml/device_description.xml")!
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 1.5
            config.timeoutIntervalForResource = 2.0
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let body = String(data: data, encoding: .utf8),
                  body.contains("Sonos") || body.contains("ZonePlayer") else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    /// Get the local IP address of the primary network interface.
    private func getLocalIPAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var bestIP: String?

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee

            // Only IPv4, up, non-loopback
            guard addr.sa_family == UInt8(AF_INET),
                  (flags & IFF_UP) != 0,
                  (flags & IFF_LOOPBACK) == 0 else { continue }

            let name = String(cString: ptr.pointee.ifa_name)

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                ptr.pointee.ifa_addr, socklen_t(addr.sa_len),
                &hostname, socklen_t(hostname.count),
                nil, 0, NI_NUMERICHOST
            ) == 0 {
                let ip = String(cString: hostname)
                // Prefer en0 (Wi-Fi/Ethernet), but take any non-loopback
                if name == "en0" {
                    return ip
                }
                if bestIP == nil {
                    bestIP = ip
                }
            }
        }

        return bestIP
    }

    /// Extract the /24 subnet prefix from an IP (e.g. "192.168.1.50" -> "192.168.1").
    private func subnetPrefix(from ip: String) -> String {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return ip }
        return parts.dropLast().joined(separator: ".")
    }
}
