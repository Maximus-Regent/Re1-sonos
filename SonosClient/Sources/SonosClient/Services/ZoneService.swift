import Foundation

/// Manages Sonos zone groups — fetching topology, grouping/ungrouping speakers.
actor ZoneService {
    private let soap = SOAPClient()

    /// Fetch zone group topology from any device on the network.
    func getZoneGroupState(device: SonosDevice) async throws -> String {
        let response = try await soap.send(
            to: device.baseURL,
            service: .zoneGroupTopology,
            action: "GetZoneGroupState",
            arguments: []
        )
        return response
    }

    /// Parse zone group topology XML into groups.
    func parseZoneGroups(from xml: String, knownDevices: [String: SonosDevice]) -> [SonosGroup] {
        // Extract ZoneGroupState content
        guard let state = XMLHelper.extractValue(tag: "ZoneGroupState", from: xml) else { return [] }

        let decoded = state
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")

        var groups: [SonosGroup] = []

        // Split by ZoneGroup tags
        let groupChunks = decoded.components(separatedBy: "<ZoneGroup ")
        for chunk in groupChunks where chunk.contains("Coordinator=") {
            guard let coordinatorId = extractAttribute("Coordinator", from: chunk) else { continue }

            // Extract member UUIDs
            let memberChunks = chunk.components(separatedBy: "<ZoneGroupMember ")
            var members: [SonosDevice] = []
            var coordinator: SonosDevice?

            for memberChunk in memberChunks {
                guard let uuid = extractAttribute("UUID", from: memberChunk) else { continue }
                if let device = knownDevices[uuid] {
                    if uuid == coordinatorId {
                        coordinator = device
                    }
                    members.append(device)
                }
            }

            if let coord = coordinator {
                groups.append(SonosGroup(
                    coordinator: coord,
                    members: members,
                    volume: 0,
                    muted: false
                ))
            }
        }

        return groups
    }

    /// Join a speaker to an existing group (by its coordinator).
    func joinGroup(device: SonosDevice, coordinatorDevice: SonosDevice) async throws {
        let uri = "x-rincon:\(coordinatorDevice.id)"
        _ = try await soap.send(
            to: device.baseURL,
            service: .avTransport,
            action: "SetAVTransportURI",
            arguments: [("CurrentURI", uri), ("CurrentURIMetaData", "")]
        )
    }

    /// Remove a speaker from its current group (make it standalone).
    func leaveGroup(device: SonosDevice) async throws {
        _ = try await soap.send(
            to: device.baseURL,
            service: .avTransport,
            action: "BecomeCoordinatorOfStandaloneGroup"
        )
    }

    private func extractAttribute(_ name: String, from text: String) -> String? {
        let pattern = "\(name)=\""
        guard let start = text.range(of: pattern) else { return nil }
        let valueStart = start.upperBound
        guard let end = text.range(of: "\"", range: valueStart..<text.endIndex) else { return nil }
        return String(text[valueStart..<end.lowerBound])
    }
}
