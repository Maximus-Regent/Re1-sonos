import Foundation

/// Controls volume, bass, treble, mute, and EQ on Sonos devices.
actor RenderingService {
    private let soap = SOAPClient()

    // MARK: - Volume

    func getVolume(device: SonosDevice, channel: String = "Master") async throws -> Int {
        let response = try await soap.send(
            to: device.baseURL,
            service: .renderingControl,
            action: "GetVolume",
            arguments: [("Channel", channel)]
        )
        guard let val = XMLHelper.extractValue(tag: "CurrentVolume", from: response),
              let volume = Int(val) else { return 0 }
        return volume
    }

    func setVolume(device: SonosDevice, volume: Int, channel: String = "Master") async throws {
        let clamped = max(0, min(100, volume))
        _ = try await soap.send(
            to: device.baseURL,
            service: .renderingControl,
            action: "SetVolume",
            arguments: [("Channel", channel), ("DesiredVolume", "\(clamped)")]
        )
    }

    func setRelativeVolume(device: SonosDevice, adjustment: Int, channel: String = "Master") async throws -> Int {
        let response = try await soap.send(
            to: device.baseURL,
            service: .renderingControl,
            action: "SetRelativeVolume",
            arguments: [("Channel", channel), ("Adjustment", "\(adjustment)")]
        )
        guard let val = XMLHelper.extractValue(tag: "NewVolume", from: response),
              let newVol = Int(val) else { return 0 }
        return newVol
    }

    // MARK: - Mute

    func getMute(device: SonosDevice, channel: String = "Master") async throws -> Bool {
        let response = try await soap.send(
            to: device.baseURL,
            service: .renderingControl,
            action: "GetMute",
            arguments: [("Channel", channel)]
        )
        return XMLHelper.extractValue(tag: "CurrentMute", from: response) == "1"
    }

    func setMute(device: SonosDevice, muted: Bool, channel: String = "Master") async throws {
        _ = try await soap.send(
            to: device.baseURL,
            service: .renderingControl,
            action: "SetMute",
            arguments: [("Channel", channel), ("DesiredMute", muted ? "1" : "0")]
        )
    }

    // MARK: - EQ

    func getBass(device: SonosDevice) async throws -> Int {
        let response = try await soap.send(
            to: device.baseURL,
            service: .renderingControl,
            action: "GetBass"
        )
        guard let val = XMLHelper.extractValue(tag: "CurrentBass", from: response),
              let bass = Int(val) else { return 0 }
        return bass
    }

    func setBass(device: SonosDevice, level: Int) async throws {
        let clamped = max(-10, min(10, level))
        _ = try await soap.send(
            to: device.baseURL,
            service: .renderingControl,
            action: "SetBass",
            arguments: [("DesiredBass", "\(clamped)")]
        )
    }

    func getTreble(device: SonosDevice) async throws -> Int {
        let response = try await soap.send(
            to: device.baseURL,
            service: .renderingControl,
            action: "GetTreble"
        )
        guard let val = XMLHelper.extractValue(tag: "CurrentTreble", from: response),
              let treble = Int(val) else { return 0 }
        return treble
    }

    func setTreble(device: SonosDevice, level: Int) async throws {
        let clamped = max(-10, min(10, level))
        _ = try await soap.send(
            to: device.baseURL,
            service: .renderingControl,
            action: "SetTreble",
            arguments: [("DesiredTreble", "\(clamped)")]
        )
    }

    // MARK: - Group Volume

    func getGroupVolume(device: SonosDevice) async throws -> Int {
        let response = try await soap.send(
            to: device.baseURL,
            service: .groupRenderingControl,
            action: "GetGroupVolume"
        )
        guard let val = XMLHelper.extractValue(tag: "CurrentVolume", from: response),
              let volume = Int(val) else { return 0 }
        return volume
    }

    func setGroupVolume(device: SonosDevice, volume: Int) async throws {
        let clamped = max(0, min(100, volume))
        _ = try await soap.send(
            to: device.baseURL,
            service: .groupRenderingControl,
            action: "SetGroupVolume",
            arguments: [("DesiredVolume", "\(clamped)")]
        )
    }

    func setGroupMute(device: SonosDevice, muted: Bool) async throws {
        _ = try await soap.send(
            to: device.baseURL,
            service: .groupRenderingControl,
            action: "SetGroupMute",
            arguments: [("DesiredMute", muted ? "1" : "0")]
        )
    }
}
