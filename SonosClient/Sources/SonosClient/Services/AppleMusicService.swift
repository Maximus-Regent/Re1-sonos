import Foundation
import MusicKit

/// Service layer wrapping MusicKit for browsing and searching Apple Music.
@MainActor
final class AppleMusicService: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var isLoading: Bool = false
    @Published var recentlyPlayed: MusicItemCollection<RecentlyPlayedMusicItem>?
    @Published var recommendations: [MusicPersonalRecommendation] = []
    @Published var userPlaylists: MusicItemCollection<Playlist>?

    // MARK: - Authorization

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
    }

    func checkAuthorization() {
        authorizationStatus = MusicAuthorization.currentStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    // MARK: - Search

    func search(term: String) async throws -> AppleMusicSearchResults {
        var request = MusicCatalogSearchRequest(term: term, types: [
            Song.self,
            Album.self,
            Artist.self,
            Playlist.self
        ])
        request.limit = 25
        let response = try await request.response()

        return AppleMusicSearchResults(
            songs: response.songs,
            albums: response.albums,
            artists: response.artists,
            playlists: response.playlists
        )
    }

    // MARK: - Library

    func fetchUserPlaylists() async throws -> MusicItemCollection<Playlist> {
        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.lastPlayedDate, ascending: false)
        let response = try await request.response()
        userPlaylists = response.items
        return response.items
    }

    func fetchRecentlyPlayed() async throws {
        let request = MusicRecentlyPlayedRequest<RecentlyPlayedMusicItem>()
        let response = try await request.response()
        recentlyPlayed = response.items
    }

    func fetchRecommendations() async throws {
        let request = MusicPersonalRecommendationsRequest()
        let response = try await request.response()
        recommendations = response.recommendations
    }

    // MARK: - Album Details

    func fetchAlbumTracks(album: Album) async throws -> Album {
        let detailedAlbum = try await album.with([.tracks, .artists])
        return detailedAlbum
    }

    // MARK: - Playlist Details

    func fetchPlaylistTracks(playlist: Playlist) async throws -> Playlist {
        let detailed = try await playlist.with([.tracks, .entries])
        return detailed
    }

    // MARK: - Artist Details

    func fetchArtistDetails(artist: Artist) async throws -> (topSongs: MusicItemCollection<Song>?, albums: MusicItemCollection<Album>?) {
        let detailed = try await artist.with([.topSongs, .albums])
        return (detailed.topSongs, detailed.albums)
    }

    // MARK: - Charts

    func fetchCharts() async throws -> MusicChartsResponse {
        var request = MusicCatalogChartsRequest(kinds: [.mostPlayed, .dailyGlobalTop], types: [Song.self, Album.self, Playlist.self])
        request.limit = 25
        return try await request.response()
    }

    // MARK: - Catalog Lookup

    func fetchCatalogAlbum(id: MusicItemID) async throws -> Album {
        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: id)
        let response = try await request.response()
        guard let album = response.items.first else {
            throw AppleMusicError.notFound
        }
        return try await album.with([.tracks, .artists])
    }

    func fetchCatalogPlaylist(id: MusicItemID) async throws -> Playlist {
        let request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: id)
        let response = try await request.response()
        guard let playlist = response.items.first else {
            throw AppleMusicError.notFound
        }
        return try await playlist.with([.tracks, .entries])
    }

    // MARK: - Errors

    enum AppleMusicError: Error, LocalizedError {
        case notAuthorized
        case notFound
        case playbackFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Apple Music not authorized"
            case .notFound: return "Item not found"
            case .playbackFailed(let msg): return "Playback failed: \(msg)"
            }
        }
    }
}

/// Container for search results across multiple types.
struct AppleMusicSearchResults {
    var songs: MusicItemCollection<Song>
    var albums: MusicItemCollection<Album>
    var artists: MusicItemCollection<Artist>
    var playlists: MusicItemCollection<Playlist>

    var isEmpty: Bool {
        songs.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty
    }
}
