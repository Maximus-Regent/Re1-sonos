import Foundation
import MusicKit

/// Bridges Apple Music content to Sonos-compatible URIs and DIDL-Lite metadata.
///
/// Sonos S1 plays Apple Music via its built-in service integration (service ID 204).
/// The URI format is: x-sonos-http:song%3a<APPLE_MUSIC_ID>.mp4?sid=204&flags=8232&sn=<SERIAL>
///
/// This bridge constructs the appropriate URIs and metadata envelopes so that
/// Apple Music content selected via MusicKit can be sent to Sonos for playback.
enum SonosAppleMusicBridge {

    /// The Sonos service ID for Apple Music.
    static let serviceId = 204

    /// Default flags for Apple Music streaming on Sonos.
    static let flags = 8232

    /// The serial number (account index). Usually 1 for the first linked AM account.
    static let serialNumber = 1

    // MARK: - URI Construction

    /// Build a Sonos-compatible URI for an Apple Music song.
    static func songURI(songId: MusicItemID) -> String {
        let encoded = "song%3a\(songId.rawValue)"
        return "x-sonos-http:\(encoded).mp4?sid=\(serviceId)&flags=\(flags)&sn=\(serialNumber)"
    }

    /// Build a Sonos-compatible URI for an Apple Music album (plays full album).
    static func albumURI(albumId: MusicItemID) -> String {
        return "x-rincon-cpcontainer:0004206calbum%3a\(albumId.rawValue)?sid=\(serviceId)&flags=\(flags)&sn=\(serialNumber)"
    }

    /// Build a Sonos-compatible URI for an Apple Music playlist.
    static func playlistURI(playlistId: MusicItemID) -> String {
        return "x-rincon-cpcontainer:1006206cplaylist%3a\(playlistId.rawValue)?sid=\(serviceId)&flags=\(flags)&sn=\(serialNumber)"
    }

    // MARK: - DIDL-Lite Metadata

    /// Build DIDL-Lite metadata XML for a song.
    static func songMetadata(song: Song) -> String {
        let title = song.title.xmlEscaped
        let artist = (song.artistName).xmlEscaped
        let album = (song.albumTitle ?? "").xmlEscaped
        let artURL = song.artwork?.url(width: 600, height: 600)?.absoluteString.xmlEscaped ?? ""
        let songId = song.id.rawValue

        return """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:upnp="http://www.upnp.org/schemas/av/didl-lite" \
        xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" \
        xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
        <item id="10032020song%3a\(songId)" parentID="" restricted="true">
        <dc:title>\(title)</dc:title>
        <upnp:class>object.item.audioItem.musicTrack</upnp:class>
        <dc:creator>\(artist)</dc:creator>
        <upnp:album>\(album)</upnp:album>
        <upnp:albumArtURI>\(artURL)</upnp:albumArtURI>
        <desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">SA_RINCON\(serviceId)_X_#Svc\(serviceId)-0-Token</desc>
        </item>
        </DIDL-Lite>
        """
    }

    /// Build DIDL-Lite metadata XML for an album.
    static func albumMetadata(album: Album) -> String {
        let title = album.title.xmlEscaped
        let artist = (album.artistName).xmlEscaped
        let artURL = album.artwork?.url(width: 600, height: 600)?.absoluteString.xmlEscaped ?? ""
        let albumId = album.id.rawValue

        return """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:upnp="http://www.upnp.org/schemas/av/didl-lite" \
        xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" \
        xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
        <item id="0004206calbum%3a\(albumId)" parentID="" restricted="true">
        <dc:title>\(title)</dc:title>
        <upnp:class>object.container.album.musicAlbum</upnp:class>
        <dc:creator>\(artist)</dc:creator>
        <upnp:albumArtURI>\(artURL)</upnp:albumArtURI>
        <desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">SA_RINCON\(serviceId)_X_#Svc\(serviceId)-0-Token</desc>
        </item>
        </DIDL-Lite>
        """
    }

    /// Build DIDL-Lite metadata XML for a playlist.
    static func playlistMetadata(playlist: Playlist) -> String {
        let title = playlist.name.xmlEscaped
        let artURL = playlist.artwork?.url(width: 600, height: 600)?.absoluteString.xmlEscaped ?? ""
        let playlistId = playlist.id.rawValue

        return """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:upnp="http://www.upnp.org/schemas/av/didl-lite" \
        xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" \
        xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
        <item id="1006206cplaylist%3a\(playlistId)" parentID="" restricted="true">
        <dc:title>\(title)</dc:title>
        <upnp:class>object.container.playlistContainer</upnp:class>
        <upnp:albumArtURI>\(artURL)</upnp:albumArtURI>
        <desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">SA_RINCON\(serviceId)_X_#Svc\(serviceId)-0-Token</desc>
        </item>
        </DIDL-Lite>
        """
    }

    // MARK: - Metadata for adding to queue

    /// Build DIDL-Lite for adding a single song to the Sonos queue.
    static func songQueueMetadata(song: Song) -> String {
        songMetadata(song: song)
    }
}
