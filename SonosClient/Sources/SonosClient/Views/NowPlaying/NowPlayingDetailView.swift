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

            if coordinator.devices.isEmpty && !coordinator.isDiscovering {
                VStack(spacing: 12) {
                    Button("Search for Devices") {
                        coordinator.startDiscovery()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)

                    ManualIPEntryView()
                }
            } else if coordinator.isDiscovering {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Searching for Sonos speakers...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }

            // Discovery log
            if !coordinator.discoveryLog.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(coordinator.discoveryLog.suffix(5), id: \.self) { entry in
                        Text(entry)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.top, 12)
                .frame(maxWidth: 400)
            }

            Spacer()
        }
    }
}

/// Inline manual IP entry field.
struct ManualIPEntryView: View {
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var ipAddress: String = ""
    @State private var isAdding: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Text("Or enter a Sonos IP address:")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                TextField("e.g. 192.168.1.100", text: $ipAddress)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit { addDevice() }

                Button {
                    addDevice()
                } label: {
                    if isAdding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Connect")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(ipAddress.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            }
        }
    }

    private func addDevice() {
        guard !ipAddress.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isAdding = true
        Task {
            await coordinator.addDeviceManually(ip: ipAddress)
            isAdding = false
        }
    }
}
