import SwiftUI

/// Compact menu bar mini player popover.
struct MenuBarPlayerView: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        VStack(spacing: 10) {
            // Track info
            if let info = coordinator.transportInfo {
                HStack(spacing: 10) {
                    AlbumArtView(
                        track: info.currentTrack,
                        baseURL: coordinator.selectedGroup?.coordinator.baseURL,
                        size: 48
                    )
                    .cornerRadius(4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.currentTrack.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(info.currentTrack.artist)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                // Progress bar
                if info.currentTrack.duration > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.accentColor)
                                .frame(
                                    width: max(0, geo.size.width * min(1, info.currentPosition / info.currentTrack.duration)),
                                    height: 3
                                )
                        }
                    }
                    .frame(height: 3)
                }
            } else {
                HStack {
                    Image(systemName: "hifispeaker.fill")
                        .foregroundColor(.secondary)
                    Text("Not Playing")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // Playback controls
            HStack(spacing: 16) {
                Button {
                    Task { await coordinator.previous() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await coordinator.togglePlayPause() }
                } label: {
                    Image(systemName: coordinator.transportInfo?.state.isPlaying == true ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await coordinator.next() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }

            // Volume
            HStack(spacing: 6) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 14)

                Slider(value: volumeBinding, in: 0...100, step: 1)
                    .controlSize(.small)

                Text("\(coordinator.volume)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 22, alignment: .trailing)
            }

            Divider()

            // Room picker
            if !coordinator.groups.isEmpty {
                Menu {
                    ForEach(coordinator.groups) { group in
                        Button {
                            coordinator.selectGroup(group)
                        } label: {
                            HStack {
                                Text(group.displayName)
                                if group.id == coordinator.selectedGroup?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 10))
                        Text(coordinator.selectedGroup?.displayName ?? "Select Room")
                            .font(.system(size: 11))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.primary)
                }
                .menuStyle(.borderlessButton)
            }

            // Open main app
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title != "" || $0.isKeyWindow }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Text("Open App")
                    .font(.system(size: 11))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 280)
        .onAppear {
            if coordinator.devices.isEmpty {
                coordinator.startDiscovery()
            }
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(coordinator.volume) },
            set: { newVal in Task { await coordinator.setVolume(Int(newVal)) } }
        )
    }
}
