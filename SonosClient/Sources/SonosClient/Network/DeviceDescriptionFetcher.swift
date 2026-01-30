import Foundation

/// Fetches and parses the UPnP device description XML from a Sonos speaker.
enum DeviceDescriptionFetcher {

    static func fetch(ip: String, port: Int) async throws -> SonosDevice? {
        let url = URL(string: "http://\(ip):\(port)/xml/device_description.xml")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let xml = String(data: data, encoding: .utf8) else { return nil }
        return parse(xml: xml, ip: ip, port: port)
    }

    private static func parse(xml: String, ip: String, port: Int) -> SonosDevice? {
        guard let udn = XMLHelper.extractValue(tag: "UDN", from: xml) else { return nil }

        let id = udn.replacingOccurrences(of: "uuid:", with: "")
        let roomName = XMLHelper.extractValue(tag: "roomName", from: xml)
            ?? XMLHelper.extractValue(tag: "friendlyName", from: xml)
            ?? "Unknown Room"
        let modelName = XMLHelper.extractValue(tag: "modelName", from: xml) ?? "Sonos"
        let modelNumber = XMLHelper.extractValue(tag: "modelNumber", from: xml) ?? ""
        let softwareVersion = XMLHelper.extractValue(tag: "softwareVersion", from: xml) ?? ""
        let hardwareVersion = XMLHelper.extractValue(tag: "hardwareVersion", from: xml) ?? ""

        return SonosDevice(
            id: id,
            ip: ip,
            port: port,
            roomName: roomName,
            modelName: modelName,
            modelNumber: modelNumber,
            softwareVersion: softwareVersion,
            hardwareVersion: hardwareVersion,
            icon: SonosDevice.iconForModel(modelName),
            groupId: "",
            isGroupCoordinator: false,
            groupMembers: []
        )
    }
}
