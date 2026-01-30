import SwiftUI
import MusicKit

/// Search view for finding songs, albums, artists, and playlists on Apple Music.
struct AppleMusicSearchView: View {
    let musicService: AppleMusicService
    let onNavigate: (MusicDestination) -> Void

    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var searchText: String = ""
    @State private var results: AppleMusicSearchResults?
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search Apple Music...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onSubmit { performSearch() }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        results = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Results
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let results {
                if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No results for \"\(searchText)\"")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    searchResultsList(results)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Search for songs, albums, artists, or playlists")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            // Debounced search
            searchTask?.cancel()
            guard !newValue.isEmpty else {
                results = nil
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                performSearch()
            }
        }
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            isSearching = true
            do {
                results = try await musicService.search(term: searchText)
            } catch {
                print("[Search] Error: \(error)")
            }
            isSearching = false
        }
    }

    private func searchResultsList(_ results: AppleMusicSearchResults) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Songs
                if !results.songs.isEmpty {
                    Text("Songs")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.horizontal, 16)
                    VStack(spacing: 0) {
                        ForEach(Array(results.songs.prefix(10).enumerated()), id: \.element.id) { index, song in
                            SongRow(song: song, index: index + 1, onNavigate: onNavigate)
                            if index < min(9, results.songs.count - 1) {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // Albums
                if !results.albums.isEmpty {
                    Text("Albums")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.horizontal, 16)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(results.albums, id: \.id) { album in
                                AlbumCard(album: album) {
                                    onNavigate(.album(album))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Artists
                if !results.artists.isEmpty {
                    Text("Artists")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.horizontal, 16)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(results.artists, id: \.id) { artist in
                                ArtistCard(artist: artist) {
                                    onNavigate(.artist(artist))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Playlists
                if !results.playlists.isEmpty {
                    Text("Playlists")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.horizontal, 16)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(results.playlists, id: \.id) { playlist in
                                PlaylistCard(playlist: playlist) {
                                    onNavigate(.playlist(playlist))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }
}
