import SwiftUI

/// Full now-playing detail view shown in the main content area.
struct NowPlayingDetailView: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        VStack(spacing: 0) {
            if let info = coordinator.transportInfo {
                GeometryReader { geo in
                    let size = min(geo.size.width * 0.5, geo.size.height * 0.55)
                    VStack(spacing: 20) {
                        Spacer()

                        // Album Art
                        AlbumArtView(
                            track: info.currentTrack,
                            baseURL: coordinator.selectedGroup?.coordinator.baseURL,
                            size: size
                        )

                        // Track Info
                        VStack(spacing: 6) {
                            Text(info.currentTrack.title)
                                .font(.system(size: 22, weight: .semibold))
                                .lineLimit(1)

                            Text(info.currentTrack.artist)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            if !info.currentTrack.album.isEmpty {
                                Text(info.currentTrack.album)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }

                        // Progress
                        ProgressBarView(
                            currentPosition: info.currentPosition,
                            duration: info.currentTrack.duration,
                            onSeek: { position in
                                Task { await coordinator.seek(to: position) }
                            }
                        )
                        .padding(.horizontal, 40)

                        // Playback Controls
                        PlaybackControlsView()
                            .padding(.bottom, 8)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                emptyState
            }
        }
        .padding(24)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hifispeaker.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No Room Selected")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Select a room from the sidebar to begin")
                .font(.body)
                .foregroundColor(.secondary.opacity(0.7))

            if coordinator.devices.isEmpty {
                Button("Search for Devices") {
                    coordinator.startDiscovery()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            Spacer()
        }
    }
}
