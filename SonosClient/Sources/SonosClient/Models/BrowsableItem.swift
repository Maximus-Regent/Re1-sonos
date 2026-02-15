import Foundation

/// Represents a browsable item from the Sonos music library (artist, album, track, genre, etc.)
struct BrowsableItem: Identifiable, Equatable {
    let id: String
    let parentID: String
    var title: String
    var itemClass: String
    var albumArtURI: String
    var uri: String
    var artist: String
    var album: String

    var isContainer: Bool {
        itemClass.contains("container") || itemClass.contains("object.container")
    }

    func albumArtURL(relativeTo baseURL: URL) -> URL? {
        if albumArtURI.hasPrefix("http") {
            return URL(string: albumArtURI)
        }
        guard !albumArtURI.isEmpty else { return nil }
        return URL(string: albumArtURI, relativeTo: baseURL)
    }
}

/// Result from a ContentDirectory Browse operation.
struct BrowseResult {
    var items: [BrowsableItem]
    var totalMatches: Int
    var numberReturned: Int
}

/// Top-level library sections for browsing.
enum LibrarySection: String, CaseIterable, Identifiable {
    case artists = "A:ARTIST"
    case albums = "A:ALBUM"
    case genres = "A:GENRE"
    case tracks = "A:TRACK"
    case composers = "A:COMPOSER"
    case importedPlaylists = "A:PLAYLISTS"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .artists: return "Artists"
        case .albums: return "Albums"
        case .genres: return "Genres"
        case .tracks: return "Tracks"
        case .composers: return "Composers"
        case .importedPlaylists: return "Imported Playlists"
        }
    }

    var icon: String {
        switch self {
        case .artists: return "person.2"
        case .albums: return "square.stack"
        case .genres: return "guitars"
        case .tracks: return "music.note"
        case .composers: return "music.quarternote.3"
        case .importedPlaylists: return "music.note.list"
        }
    }
}

/// Breadcrumb for library navigation.
struct LibraryBreadcrumb: Identifiable, Equatable {
    let id = UUID()
    let objectID: String
    let title: String
}
