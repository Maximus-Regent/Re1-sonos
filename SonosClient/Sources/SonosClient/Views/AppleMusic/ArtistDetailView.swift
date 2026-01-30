import SwiftUI
import MusicKit

/// Detail view for an Apple Music artist: top songs and albums.
struct ArtistDetailView: View {
    let artist: Artist
    let musicService: AppleMusicService
    let onNavigate: (MusicDestination) -> Void
    @EnvironmentObject var coordinator: SonosCoordinator

    @State private var topSongs: MusicItemCollection<Song>?
    @State private var albums: MusicItemCollection<Album>?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Artist header
                HStack(spacing: 16) {
                    if let artwork = artist.artwork {
                        ArtworkImage(artwork, width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    } else {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .overlay(Image(systemName: "music.mic").font(.largeTitle).foregroundColor(.secondary.opacity(0.3)))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Artist")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(artist.name)
                            .font(.system(size: 28, weight: .bold))

                        if let genres = artist.genreNames, !genres.isEmpty {
                            Text(genres.joined(separator: ", "))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Top Songs
                    if let songs = topSongs, !songs.isEmpty {
                        Text("Top Songs")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(Array(songs.prefix(10).enumerated()), id: \.element.id) { index, song in
                                SongRow(song: song, index: index + 1, onNavigate: onNavigate)
                                if index < min(9, songs.count - 1) {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    // Albums
                    if let albums, !albums.isEmpty {
                        Text("Albums")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 20)

                        let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)]
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(albums, id: \.id) { album in
                                AlbumCard(album: album) {
                                    onNavigate(.album(album))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .task {
            do {
                let details = try await musicService.fetchArtistDetails(artist: artist)
                topSongs = details.topSongs
                albums = details.albums
            } catch {
                print("[ArtistDetail] Error: \(error)")
            }
            isLoading = false
        }
    }
}
