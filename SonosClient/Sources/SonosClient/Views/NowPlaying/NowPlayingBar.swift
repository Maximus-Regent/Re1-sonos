import SwiftUI
import AVKit

/// Compact now-playing bar fixed at the bottom of the window.
struct NowPlayingBar: View {
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var showEQ = false
    @State private var showSleepTimer = false

    var body: some View {
        HStack(spacing: 12) {
            // Left: mini album art + track info
            HStack(spacing: 10) {
                if let info = coordinator.transportInfo {
                    AlbumArtView(
                        track: info.currentTrack,
                        baseURL: coordinator.selectedGroup?.coordinator.baseURL,
                        size: 52
                    )
                    .cornerRadius(4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.currentTrack.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text(info.currentTrack.artist)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 120, maxWidth: 200, alignment: .leading)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not Playing")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 120, maxWidth: 200, alignment: .leading)
                }
            }

            Spacer()

            // Center: playback controls
            VStack(spacing: 4) {
                HStack(spacing: 16) {
                    // Shuffle
                    Button {
                        Task { await coordinator.toggleShuffle() }
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 12))
                            .foregroundColor(coordinator.transportInfo?.playMode.isShuffled == true ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    // Previous
                    Button {
                        Task { await coordinator.previous() }
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    // Play/Pause
                    Button {
                        Task { await coordinator.togglePlayPause() }
                    } label: {
                        Image(systemName: coordinator.transportInfo?.state.isPlaying == true ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])

                    // Next
                    Button {
                        Task { await coordinator.next() }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    // Repeat
                    Button {
                        Task { await coordinator.toggleRepeat() }
                    } label: {
                        Image(systemName: coordinator.transportInfo?.playMode.isRepeatOne == true ? "repeat.1" : "repeat")
                            .font(.system(size: 12))
                            .foregroundColor(coordinator.transportInfo?.playMode.isRepeating == true ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    // Crossfade
                    Button {
                        Task { await coordinator.toggleCrossfade() }
                    } label: {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 12))
                            .foregroundColor(coordinator.isCrossfadeEnabled ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Crossfade")
                }

                // Mini progress bar
                if let info = coordinator.transportInfo, info.currentTrack.duration > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.accentColor)
                                .frame(width: max(0, geo.size.width * min(1, info.currentPosition / info.currentTrack.duration)), height: 3)
                        }
                    }
                    .frame(height: 3)
                    .frame(maxWidth: 300)
                }
            }
            .frame(maxWidth: 400)

            Spacer()

            // Right: EQ, sleep timer, volume
            HStack(spacing: 8) {
                // EQ button
                Button {
                    showEQ.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Equalizer")
                .popover(isPresented: $showEQ) {
                    EQControlView()
                        .environmentObject(coordinator)
                }

                // Sleep timer button
                Button {
                    showSleepTimer.toggle()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 12))
                        if coordinator.sleepTimerRemaining != nil {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                                .offset(x: 3, y: -3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Sleep Timer")
                .popover(isPresented: $showSleepTimer) {
                    SleepTimerView()
                        .environmentObject(coordinator)
                }

                // AirPlay route picker
                AirPlayRoutePickerView()
                    .frame(width: 20, height: 20)
                    .help("AirPlay")

                Divider()
                    .frame(height: 16)

                // Volume
                Button {
                    Task { await coordinator.toggleMute() }
                } label: {
                    Image(systemName: coordinator.isMuted ? "speaker.slash.fill" : volumeIcon)
                        .font(.system(size: 12))
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                Slider(value: volumeBinding, in: 0...100, step: 1)
                    .frame(width: 100)
                    .controlSize(.small)

                Text("\(coordinator.volume)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var volumeIcon: String {
        if coordinator.volume == 0 { return "speaker.fill" }
        if coordinator.volume < 33 { return "speaker.wave.1.fill" }
        if coordinator.volume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(coordinator.volume) },
            set: { newVal in
                Task { await coordinator.setVolume(Int(newVal)) }
            }
        )
    }
}

// MARK: - AirPlay Route Picker

/// NSViewRepresentable wrapping AVRoutePickerView for AirPlay destination selection.
struct AirPlayRoutePickerView: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.isRoutePickerButtonBordered = false
        return picker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
