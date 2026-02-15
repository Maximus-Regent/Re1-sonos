import Foundation
import MusicKit

/// Actor wrapping MusicKit APIs for Apple Music browse, search, and playback.
actor AppleMusicService {

    // MARK: - Authorization

    func requestAuthorization() async -> MusicAuthorization.Status {
        await MusicAuthorization.request()
    }

    // MARK: - Search

    func search(term: String, types: MusicCatalogSearchable.Type...) async throws -> [AppleMusicItem] {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self, Album.self, Artist.self, Playlist.self])
        request.limit = 25
        let response = try await request.response()

        var items: [AppleMusicItem] = []

        for song in response.songs {
            items.append(AppleMusicItem(
                id: song.id.rawValue,
                title: song.title,
                subtitle: song.artistName,
                artworkURL: song.artwork?.url(width: 80, height: 80),
                itemType: .song,
                isContainer: false,
                musicKitID: song.id.rawValue
            ))
        }

        for album in response.albums {
            items.append(AppleMusicItem(
                id: album.id.rawValue,
                title: album.title,
                subtitle: album.artistName,
                artworkURL: album.artwork?.url(width: 80, height: 80),
                itemType: .album,
                isContainer: true,
                musicKitID: album.id.rawValue
            ))
        }

        for artist in response.artists {
            items.append(AppleMusicItem(
                id: artist.id.rawValue,
                title: artist.name,
                subtitle: "Artist",
                artworkURL: artist.artwork?.url(width: 80, height: 80),
                itemType: .artist,
                isContainer: true,
                musicKitID: artist.id.rawValue
            ))
        }

        for playlist in response.playlists {
            items.append(AppleMusicItem(
                id: playlist.id.rawValue,
                title: playlist.name,
                subtitle: playlist.curatorName ?? "Apple Music",
                artworkURL: playlist.artwork?.url(width: 80, height: 80),
                itemType: .playlist,
                isContainer: true,
                musicKitID: playlist.id.rawValue
            ))
        }

        return items
    }

    // MARK: - Browse

    func getTopCharts() async throws -> [AppleMusicItem] {
        var request = MusicCatalogChartsRequest(kinds: [.mostPlayed], types: [Song.self, Album.self, Playlist.self])
        request.limit = 25
        let response = try await request.response()

        var items: [AppleMusicItem] = []

        for chart in response.songCharts {
            for song in chart.items {
                items.append(AppleMusicItem(
                    id: song.id.rawValue,
                    title: song.title,
                    subtitle: song.artistName,
                    artworkURL: song.artwork?.url(width: 80, height: 80),
                    itemType: .song,
                    isContainer: false,
                    musicKitID: song.id.rawValue
                ))
            }
        }

        for chart in response.albumCharts {
            for album in chart.items {
                items.append(AppleMusicItem(
                    id: album.id.rawValue,
                    title: album.title,
                    subtitle: album.artistName,
                    artworkURL: album.artwork?.url(width: 80, height: 80),
                    itemType: .album,
                    isContainer: true,
                    musicKitID: album.id.rawValue
                ))
            }
        }

        for chart in response.playlistCharts {
            for playlist in chart.items {
                items.append(AppleMusicItem(
                    id: playlist.id.rawValue,
                    title: playlist.name,
                    subtitle: playlist.curatorName ?? "Apple Music",
                    artworkURL: playlist.artwork?.url(width: 80, height: 80),
                    itemType: .playlist,
                    isContainer: true,
                    musicKitID: playlist.id.rawValue
                ))
            }
        }

        return items
    }

    func getArtistAlbums(id: String) async throws -> [AppleMusicItem] {
        let artistID = MusicItemID(id)
        let request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: artistID)
        let response = try await request.response()
        guard let artist = response.items.first else { return [] }

        let detailedArtist = try await artist.with([.albums])
        guard let albums = detailedArtist.albums else { return [] }

        return albums.map { album in
            AppleMusicItem(
                id: album.id.rawValue,
                title: album.title,
                subtitle: album.artistName,
                artworkURL: album.artwork?.url(width: 80, height: 80),
                itemType: .album,
                isContainer: true,
                musicKitID: album.id.rawValue
            )
        }
    }

    func getAlbumTracks(id: String) async throws -> [AppleMusicItem] {
        let albumID = MusicItemID(id)
        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: albumID)
        let response = try await request.response()
        guard let album = response.items.first else { return [] }

        let detailedAlbum = try await album.with([.tracks])
        guard let tracks = detailedAlbum.tracks else { return [] }

        return tracks.map { track in
            AppleMusicItem(
                id: track.id.rawValue,
                title: track.title,
                subtitle: track.artistName,
                artworkURL: track.artwork?.url(width: 80, height: 80),
                itemType: .song,
                isContainer: false,
                musicKitID: track.id.rawValue
            )
        }
    }

    func getPlaylistTracks(id: String) async throws -> [AppleMusicItem] {
        let playlistID = MusicItemID(id)
        let request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: playlistID)
        let response = try await request.response()
        guard let playlist = response.items.first else { return [] }

        let detailedPlaylist = try await playlist.with([.tracks])
        guard let tracks = detailedPlaylist.tracks else { return [] }

        return tracks.map { track in
            AppleMusicItem(
                id: track.id.rawValue,
                title: track.title,
                subtitle: track.artistName,
                artworkURL: track.artwork?.url(width: 80, height: 80),
                itemType: .song,
                isContainer: false,
                musicKitID: track.id.rawValue
            )
        }
    }

    // MARK: - Playback

    func play(item: AppleMusicItem) async throws {
        let player = ApplicationMusicPlayer.shared
        switch item.itemType {
        case .song:
            let songID = MusicItemID(item.musicKitID)
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songID)
            let response = try await request.response()
            guard let song = response.items.first else { return }
            player.queue = [song]
            try await player.play()

        case .album:
            let albumID = MusicItemID(item.musicKitID)
            let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: albumID)
            let response = try await request.response()
            guard let album = response.items.first else { return }
            player.queue = [album]
            try await player.play()

        case .playlist:
            let playlistID = MusicItemID(item.musicKitID)
            let request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: playlistID)
            let response = try await request.response()
            guard let playlist = response.items.first else { return }
            player.queue = [playlist]
            try await player.play()

        default:
            break
        }
    }

    func playPause() async {
        let player = ApplicationMusicPlayer.shared
        if player.state.playbackStatus == .playing {
            player.pause()
        } else {
            try? await player.play()
        }
    }

    func next() async {
        let player = ApplicationMusicPlayer.shared
        try? await player.skipToNextEntry()
    }

    func previous() async {
        let player = ApplicationMusicPlayer.shared
        try? await player.skipToPreviousEntry()
    }
}
