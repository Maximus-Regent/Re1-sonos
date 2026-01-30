import SwiftUI
import MusicKit

/// Detail view for an Apple Music album: header with art, track listing, play controls.
struct AlbumDetailView: View {
    let album: Album
    let musicService: AppleMusicService
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var detailedAlbum: Album?
    @State private var isLoading = true

    var displayAlbum: Album { detailedAlbum ?? album }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top, spacing: 20) {
                    // Album art
                    if let artwork = displayAlbum.artwork {
                        ArtworkImage(artwork, width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundColor(.secondary.opacity(0.3)))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(displayAlbum.title)
                            .font(.system(size: 24, weight: .bold))
                            .lineLimit(2)

                        Text(displayAlbum.artistName)
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)

                        if let genre = displayAlbum.genreNames.first {
                            Text(genre)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        if let releaseDate = displayAlbum.releaseDate {
                            Text(releaseDate, style: .date)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        if let trackCount = displayAlbum.trackCount {
                            Text("\(trackCount) tracks")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Action buttons
                        HStack(spacing: 10) {
                            Button {
                                Task { await playAlbum() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)

                            Button {
                                Task { await shuffleAlbum() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Button {
                                Task { await addAlbumToQueue() }
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
                } else if let tracks = displayAlbum.tracks {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            AlbumTrackRow(track: track, index: index + 1) {
                                Task { await playSong(track) }
                            } onAddToQueue: {
                                Task { await addSongToQueue(track) }
                            }
                            if index < tracks.count - 1 {
                                Divider().padding(.leading, 44)
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
                detailedAlbum = try await musicService.fetchAlbumTracks(album: album)
            } catch {
                print("[AlbumDetail] Error loading tracks: \(error)")
            }
            isLoading = false
        }
    }

    // MARK: - Playback Actions

    private func playAlbum() async {
        guard coordinator.selectedGroup != nil else {
            coordinator.errorMessage = "Select a room first"
            return
        }
        await coordinator.playAppleMusicAlbum(album: displayAlbum)
    }

    private func shuffleAlbum() async {
        guard coordinator.selectedGroup != nil else {
            coordinator.errorMessage = "Select a room first"
            return
        }
        await coordinator.playAppleMusicAlbum(album: displayAlbum, shuffle: true)
    }

    private func addAlbumToQueue() async {
        guard coordinator.selectedGroup != nil else {
            coordinator.errorMessage = "Select a room first"
            return
        }
        await coordinator.addAppleMusicAlbumToQueue(album: displayAlbum)
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

struct AlbumTrackRow: View {
    let track: Song
    let index: Int
    let onPlay: () -> Void
    let onAddToQueue: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Track number
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

            // Track name
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                if track.artistName != "" {
                    Text(track.artistName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Duration
            if let duration = track.duration {
                Text(XMLHelper.formatDuration(duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Add to queue
            if isHovering {
                Button {
                    onAddToQueue()
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
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { onPlay() }
    }
}
