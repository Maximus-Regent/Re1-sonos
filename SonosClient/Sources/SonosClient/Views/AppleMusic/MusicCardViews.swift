import SwiftUI
import MusicKit

// MARK: - Album Card

struct AlbumCard: View {
    let album: Album
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                if let artwork = album.artwork {
                    ArtworkImage(artwork, width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 150, height: 150)
                        .overlay(Image(systemName: "music.note").font(.title2).foregroundColor(.secondary.opacity(0.3)))
                }
                Text(album.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(album.artistName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 150)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Playlist Card

struct PlaylistCard: View {
    let playlist: Playlist
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                if let artwork = playlist.artwork {
                    ArtworkImage(artwork, width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 150, height: 150)
                        .overlay(Image(systemName: "music.note.list").font(.title2).foregroundColor(.white.opacity(0.5)))
                }
                Text(playlist.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if let curator = playlist.curatorName {
                    Text(curator)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 150)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Artist Card

struct ArtistCard: View {
    let artist: Artist
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                if let artwork = artist.artwork {
                    ArtworkImage(artwork, width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(Image(systemName: "music.mic").font(.title2).foregroundColor(.secondary.opacity(0.3)))
                }
                Text(artist.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: 120)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Song Row

struct SongRow: View {
    let song: Song
    let index: Int
    var onNavigate: ((MusicDestination) -> Void)?
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // Index / play icon
            ZStack {
                if isHovering {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                } else {
                    Text("\(index)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 28, alignment: .center)

            // Album art
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 36, height: 36)
            }

            // Title + artist
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Album name
            if let albumTitle = song.albumTitle {
                Text(albumTitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .trailing)
            }

            // Duration
            if let duration = song.duration {
                Text(XMLHelper.formatDuration(duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Hover actions
            if isHovering {
                Button {
                    Task { await coordinator.addAppleMusicSongToQueue(song: song) }
                } label: {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Add to Queue")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) {
            Task { await coordinator.playAppleMusicSong(song: song) }
        }
    }
}
