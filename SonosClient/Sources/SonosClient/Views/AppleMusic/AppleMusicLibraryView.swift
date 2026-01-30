import SwiftUI
import MusicKit

/// Library section: shows user's playlists and library content.
struct AppleMusicLibraryView: View {
    let musicService: AppleMusicService
    let onNavigate: (MusicDestination) -> Void

    @State private var playlists: MusicItemCollection<Playlist>?
    @State private var libraryAlbums: MusicItemCollection<Album>?
    @State private var libraryArtists: MusicItemCollection<Artist>?
    @State private var librarySongs: MusicItemCollection<Song>?
    @State private var selectedLibTab: LibraryTab = .playlists
    @State private var isLoading = true

    enum LibraryTab: String, CaseIterable {
        case playlists = "Playlists"
        case albums = "Albums"
        case artists = "Artists"
        case songs = "Songs"

        var icon: String {
            switch self {
            case .playlists: return "music.note.list"
            case .albums: return "square.stack"
            case .artists: return "music.mic"
            case .songs: return "music.note"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Library sub-tabs
            HStack(spacing: 4) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    Button {
                        selectedLibTab = tab
                        Task { await loadTab(tab) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selectedLibTab == tab ? Color.secondary.opacity(0.12) : Color.clear)
                        )
                        .foregroundColor(selectedLibTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch selectedLibTab {
                case .playlists:
                    playlistsList
                case .albums:
                    albumsGrid
                case .artists:
                    artistsList
                case .songs:
                    songsList
                }
            }
        }
        .task {
            await loadTab(.playlists)
        }
    }

    // MARK: - Playlists

    private var playlistsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let playlists, !playlists.isEmpty {
                    ForEach(playlists, id: \.id) { playlist in
                        Button {
                            onNavigate(.playlist(playlist))
                        } label: {
                            HStack(spacing: 10) {
                                if let artwork = playlist.artwork {
                                    ArtworkImage(artwork, width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                        .overlay(Image(systemName: "music.note.list").foregroundColor(.secondary.opacity(0.3)))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    if let curator = playlist.curatorName {
                                        Text(curator)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 70)
                    }
                } else {
                    emptyView("No playlists found")
                }
            }
        }
    }

    // MARK: - Albums Grid

    private var albumsGrid: some View {
        ScrollView {
            let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)]
            LazyVGrid(columns: columns, spacing: 16) {
                if let albums = libraryAlbums {
                    ForEach(albums, id: \.id) { album in
                        AlbumCard(album: album) {
                            onNavigate(.album(album))
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Artists

    private var artistsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let artists = libraryArtists, !artists.isEmpty {
                    ForEach(artists, id: \.id) { artist in
                        Button {
                            onNavigate(.artist(artist))
                        } label: {
                            HStack(spacing: 10) {
                                if let artwork = artist.artwork {
                                    ArtworkImage(artwork, width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                        .overlay(Image(systemName: "music.mic").font(.system(size: 14)).foregroundColor(.secondary.opacity(0.4)))
                                }
                                Text(artist.name)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 66)
                    }
                } else {
                    emptyView("No artists found")
                }
            }
        }
    }

    // MARK: - Songs

    @EnvironmentObject var coordinator: SonosCoordinator

    private var songsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let songs = librarySongs, !songs.isEmpty {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SongRow(song: song, index: index + 1) { dest in
                            onNavigate(dest)
                        }
                        if index < songs.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                } else {
                    emptyView("No songs found")
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Loading

    private func loadTab(_ tab: LibraryTab) async {
        isLoading = true
        do {
            switch tab {
            case .playlists:
                playlists = try await musicService.fetchUserPlaylists()
            case .albums:
                var request = MusicLibraryRequest<Album>()
                request.sort(by: \.title, ascending: true)
                let response = try await request.response()
                libraryAlbums = response.items
            case .artists:
                var request = MusicLibraryRequest<Artist>()
                request.sort(by: \.name, ascending: true)
                let response = try await request.response()
                libraryArtists = response.items
            case .songs:
                var request = MusicLibraryRequest<Song>()
                request.sort(by: \.title, ascending: true)
                let response = try await request.response()
                librarySongs = response.items
            }
        } catch {
            print("[Library] Failed to load \(tab): \(error)")
        }
        isLoading = false
    }

    private func emptyView(_ message: String) -> some View {
        Text(message)
            .font(.body)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
