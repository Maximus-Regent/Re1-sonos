import Foundation

/// Represents a single Sonos speaker/device on the network.
struct SonosDevice: Identifiable, Hashable {
    let id: String // UUID from UPnP
    let ip: String
    let port: Int
    var roomName: String
    var modelName: String
    var modelNumber: String
    var softwareVersion: String
    var hardwareVersion: String
    var icon: String // SF Symbol name derived from model

    // Zone/Group info
    var groupId: String
    var isGroupCoordinator: Bool
    var groupMembers: [String] // device IDs

    var baseURL: URL {
        URL(string: "http://\(ip):\(port)")!
    }

    static func == (lhs: SonosDevice, rhs: SonosDevice) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SonosDevice {
    /// Derive an appropriate SF Symbol based on Sonos model.
    static func iconForModel(_ model: String) -> String {
        let lower = model.lowercased()
        if lower.contains("sub") { return "speaker.fill" }
        if lower.contains("beam") || lower.contains("arc") || lower.contains("ray") || lower.contains("playbar") || lower.contains("playbase") {
            return "tv.and.hifispeaker.fill"
        }
        if lower.contains("move") || lower.contains("roam") { return "speaker.wave.2.fill" }
        if lower.contains("one") || lower.contains("play:1") { return "hifispeaker.fill" }
        if lower.contains("five") || lower.contains("play:5") { return "hifispeaker.2.fill" }
        if lower.contains("port") || lower.contains("amp") || lower.contains("connect") { return "hifispeaker.and.homepod.fill" }
        return "hifispeaker.fill"
    }
}
