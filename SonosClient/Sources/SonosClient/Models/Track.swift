import Foundation

/// Represents a track (currently playing or in the queue).
struct Track: Identifiable, Equatable {
    let id: String
    var title: String
    var artist: String
    var album: String
    var albumArtURI: String
    var duration: TimeInterval
    var uri: String
    var trackNumber: Int

    /// Build a full album art URL relative to a device's base URL.
    func albumArtURL(relativeTo baseURL: URL) -> URL? {
        if albumArtURI.hasPrefix("http") {
            return URL(string: albumArtURI)
        }
        guard !albumArtURI.isEmpty else { return nil }
        return URL(string: albumArtURI, relativeTo: baseURL)
    }

    static var empty: Track {
        Track(
            id: UUID().uuidString,
            title: "Not Playing",
            artist: "",
            album: "",
            albumArtURI: "",
            duration: 0,
            uri: "",
            trackNumber: 0
        )
    }
}
