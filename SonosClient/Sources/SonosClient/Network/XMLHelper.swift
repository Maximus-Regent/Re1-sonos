import Foundation

/// Lightweight XML parsing helpers for Sonos SOAP responses.
enum XMLHelper {

    /// Extract the text content of a given XML tag from a string.
    /// Handles both plain tags (`<Tag>`) and namespace-prefixed tags (`<ns:Tag>`).
    static func extractValue(tag: String, from xml: String) -> String? {
        // Build patterns: plain tag, plain tag with attributes, and any namespace prefix
        let patterns = [
            "<\(tag)>", "<\(tag) ",
            ":\(tag)>", ":\(tag) ",
        ]
        for prefix in patterns {
            guard let startRange = xml.range(of: prefix) else { continue }
            let searchStart: String.Index
            if prefix.hasSuffix(" ") {
                // Find the closing > of the opening tag (skip attributes)
                guard let closeAngle = xml.range(of: ">", range: startRange.upperBound..<xml.endIndex) else { continue }
                searchStart = closeAngle.upperBound
            } else {
                searchStart = startRange.upperBound
            }
            // For closing tag, also match namespace-prefixed variants
            let closingPatterns = ["</\(tag)>"]
            var endRange: Range<String.Index>?
            for closing in closingPatterns {
                endRange = xml.range(of: closing, range: searchStart..<xml.endIndex)
                if endRange != nil { break }
            }
            // Also try namespace-prefixed closing tag (e.g. </ns:Tag>)
            if endRange == nil {
                endRange = xml.range(of: ":\(tag)>", range: searchStart..<xml.endIndex)
                if let er = endRange {
                    // Walk back to find the '</' before the namespace prefix
                    var idx = er.lowerBound
                    while idx > searchStart {
                        let prev = xml.index(before: idx)
                        if xml[prev] == "/" {
                            let prevPrev = xml.index(before: prev)
                            if xml[prevPrev] == "<" {
                                endRange = prevPrev..<er.upperBound
                                break
                            }
                        }
                        if xml[prev] == "<" || xml[prev] == ">" { break }
                        idx = prev
                    }
                }
            }
            guard let end = endRange else { continue }
            // Extract content between opening and closing tags
            let contentEnd: String.Index
            if end.lowerBound >= searchStart {
                // For namespace-prefixed closing, find the '<' that starts the closing tag
                contentEnd = xml[searchStart..<end.upperBound].range(of: "</", options: .backwards, range: searchStart..<end.upperBound)?.lowerBound ?? end.lowerBound
            } else {
                continue
            }
            return String(xml[searchStart..<contentEnd])
        }
        return nil
    }

    /// Extract multiple occurrences of a tag's content.
    static func extractAllValues(tag: String, from xml: String) -> [String] {
        var results: [String] = []
        var searchRange = xml.startIndex..<xml.endIndex

        while let startRange = xml.range(of: "<\(tag)>", range: searchRange) {
            let contentStart = startRange.upperBound
            guard let endRange = xml.range(of: "</\(tag)>", range: contentStart..<xml.endIndex) else { break }
            results.append(String(xml[contentStart..<endRange.lowerBound]))
            searchRange = endRange.upperBound..<xml.endIndex
        }
        return results
    }

    /// Parse a DIDL-Lite metadata string into a Track.
    static func parseTrackMetadata(_ didl: String, trackURI: String = "") -> Track? {
        // DIDL might be HTML-escaped in SOAP response
        let decoded = didl
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")

        let title = extractValue(tag: "dc:title", from: decoded) ?? "Unknown"
        let artist = extractValue(tag: "dc:creator", from: decoded) ?? extractValue(tag: "r:albumArtist", from: decoded) ?? ""
        let album = extractValue(tag: "upnp:album", from: decoded) ?? ""
        let albumArtURI = extractValue(tag: "upnp:albumArtURI", from: decoded) ?? ""
        let trackNumberStr = extractValue(tag: "upnp:originalTrackNumber", from: decoded) ?? "0"

        return Track(
            id: UUID().uuidString,
            title: title,
            artist: artist,
            album: album,
            albumArtURI: albumArtURI,
            duration: 0,
            uri: trackURI,
            trackNumber: Int(trackNumberStr) ?? 0
        )
    }

    /// Parse a duration string like "0:03:45" or "NOT_IMPLEMENTED" into seconds.
    static func parseDuration(_ str: String) -> TimeInterval {
        let parts = str.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 3 else { return 0 }
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }

    /// Format seconds into "mm:ss" or "h:mm:ss".
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
