import SwiftUI
import MusicKit

/// Detail view for an Apple Music playlist.
struct PlaylistDetailView: View {
    let playlist: Playlist
    let musicService: AppleMusicService
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var detailedPlaylist: Playlist?
    @State private var isLoading = true

    var displayPlaylist: Playlist { detailedPlaylist ?? playlist }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top, spacing: 20) {
                    if let artwork = displayPlaylist.artwork {
                        ArtworkImage(artwork, width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 200, height: 200)
                            .overlay(Image(systemName: "music.note.list").font(.largeTitle).foregroundColor(.white.opacity(0.5)))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(displayPlaylist.name)
                            .font(.system(size: 24, weight: .bold))
                            .lineLimit(2)

                        if let curator = displayPlaylist.curatorName {
                            Text(curator)
                                .font(.system(size: 16))
                                .foregroundColor(.accentColor)
                        }

                        if let description = displayPlaylist.standardDescription {
                            Text(description)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }

                        if let lastModified = displayPlaylist.lastModifiedDate {
                            Text("Updated \(lastModified, style: .relative) ago")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 10) {
                            Button {
                                Task { await playPlaylist() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)

                            Button {
                                Task { await shufflePlaylist() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Button {
                                Task { await addPlaylistToQueue() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "text.badge.plus")
                                    Text("Add to Queue")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)

                Divider()

                // Track listing
                if isLoading {
                    ProgressView()
                        .padding(40)
                } else if let tracks = displayPlaylist.tracks {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            PlaylistTrackRow(track: track, index: index + 1) {
                                Task { await playSong(track) }
                            } onAddToQueue: {
                                Task { await addSongToQueue(track) }
                            }
                            if index < tracks.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                } else {
                    Text("No tracks available")
                        .foregroundColor(.secondary)
                        .padding(40)
                }
            }
        }
        .task {
            do {
                detailedPlaylist = try await musicService.fetchPlaylistTracks(playlist: playlist)
            } catch {
                print("[PlaylistDetail] Error: \(error)")
            }
            isLoading = false
        }
    }

    private func playPlaylist() async {
        guard coordinator.selectedGroup != nil else {
            coordinator.errorMessage = "Select a room first"
            return
        }
        await coordinator.playAppleMusicPlaylist(playlist: displayPlaylist)
    }

    private func shufflePlaylist() async {
        guard coordinator.selectedGroup != nil else {
            coordinator.errorMessage = "Select a room first"
            return
        }
        await coordinator.playAppleMusicPlaylist(playlist: displayPlaylist, shuffle: true)
    }

    private func addPlaylistToQueue() async {
        guard coordinator.selectedGroup != nil else {
            coordinator.errorMessage = "Select a room first"
            return
        }
        await coordinator.addAppleMusicPlaylistToQueue(playlist: displayPlaylist)
    }

    private func playSong(_ song: Song) async {
        guard coordinator.selectedGroup != nil else {
            coordinator.errorMessage = "Select a room first"
            return
        }
        await coordinator.playAppleMusicSong(song: song)
    }

    private func addSongToQueue(_ song: Song) async {
        guard coordinator.selectedGroup != nil else {
            coordinator.errorMessage = "Select a room first"
            return
        }
        await coordinator.addAppleMusicSongToQueue(song: song)
    }
}

struct PlaylistTrackRow: View {
    let track: Song
    let index: Int
    let onPlay: () -> Void
    let onAddToQueue: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
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

            if let artwork = track.artwork {
                ArtworkImage(artwork, width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 36, height: 36)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.albumTitle ?? "")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: 140, alignment: .trailing)

            if let duration = track.duration {
                Text(XMLHelper.formatDuration(duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if isHovering {
                Button { onAddToQueue() } label: {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Add to Queue")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { onPlay() }
    }
}
