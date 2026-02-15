import Foundation

/// Browses the Sonos music library via ContentDirectory service.
actor MusicLibraryService {
    private let soap = SOAPClient()

    /// Browse a container in the music library.
    func browse(device: SonosDevice, objectID: String, start: Int = 0, count: Int = 100) async throws -> BrowseResult {
        let response = try await soap.send(
            to: device.baseURL,
            service: .contentDirectory,
            action: "Browse",
            arguments: [
                ("ObjectID", objectID),
                ("BrowseFlag", "BrowseDirectChildren"),
                ("Filter", "dc:title,res,dc:creator,upnp:albumArtURI,upnp:album,upnp:class,upnp:originalTrackNumber"),
                ("StartingIndex", "\(start)"),
                ("RequestedCount", "\(count)"),
                ("SortCriteria", "")
            ]
        )

        let totalMatchesStr = XMLHelper.extractValue(tag: "TotalMatches", from: response) ?? "0"
        let numberReturnedStr = XMLHelper.extractValue(tag: "NumberReturned", from: response) ?? "0"

        guard let result = XMLHelper.extractValue(tag: "Result", from: response) else {
            return BrowseResult(items: [], totalMatches: 0, numberReturned: 0)
        }

        let decoded = result
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")

        var items: [BrowsableItem] = []

        // Parse containers
        let containers = decoded.components(separatedBy: "<container ")
        for (index, container) in containers.enumerated() where index > 0 {
            let item = parseItem(from: container, index: start + items.count, isContainer: true)
            items.append(item)
        }

        // Parse items (tracks)
        let trackItems = decoded.components(separatedBy: "<item ")
        for (index, trackItem) in trackItems.enumerated() where index > 0 {
            let item = parseItem(from: trackItem, index: start + items.count, isContainer: false)
            items.append(item)
        }

        return BrowseResult(
            items: items,
            totalMatches: Int(totalMatchesStr) ?? 0,
            numberReturned: Int(numberReturnedStr) ?? 0
        )
    }

    private func parseItem(from xml: String, index: Int, isContainer: Bool) -> BrowsableItem {
        let title = XMLHelper.extractValue(tag: "dc:title", from: xml) ?? "Unknown"
        let artist = XMLHelper.extractValue(tag: "dc:creator", from: xml) ?? ""
        let album = XMLHelper.extractValue(tag: "upnp:album", from: xml) ?? ""
        let albumArt = XMLHelper.extractValue(tag: "upnp:albumArtURI", from: xml) ?? ""
        let itemClass = XMLHelper.extractValue(tag: "upnp:class", from: xml) ?? (isContainer ? "object.container" : "object.item")

        // Extract id attribute
        var itemID = "\(index)"
        if let idStart = xml.range(of: "id=\""),
           let idEnd = xml.range(of: "\"", range: idStart.upperBound..<xml.endIndex) {
            itemID = String(xml[idStart.upperBound..<idEnd.lowerBound])
        }

        // Extract parentID attribute
        var parentID = ""
        if let pidStart = xml.range(of: "parentID=\""),
           let pidEnd = xml.range(of: "\"", range: pidStart.upperBound..<xml.endIndex) {
            parentID = String(xml[pidStart.upperBound..<pidEnd.lowerBound])
        }

        // Extract URI from res tag
        var uri = ""
        if let resStart = xml.range(of: "<res "),
           let resClose = xml.range(of: ">", range: resStart.upperBound..<xml.endIndex),
           let resEnd = xml.range(of: "</res>", range: resClose.upperBound..<xml.endIndex) {
            uri = String(xml[resClose.upperBound..<resEnd.lowerBound])
        }

        return BrowsableItem(
            id: itemID,
            parentID: parentID,
            title: title,
            itemClass: itemClass,
            albumArtURI: albumArt,
            uri: uri,
            artist: artist,
            album: album
        )
    }
}
