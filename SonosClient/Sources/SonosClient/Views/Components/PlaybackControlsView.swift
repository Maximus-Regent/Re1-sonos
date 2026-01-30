import SwiftUI

/// Centered playback controls (shuffle, prev, play/pause, next, repeat).
struct PlaybackControlsView: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        HStack(spacing: 24) {
            // Shuffle
            Button {
                Task { await coordinator.toggleShuffle() }
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(coordinator.transportInfo?.playMode.isShuffled == true ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Shuffle")

            // Previous
            Button {
                Task { await coordinator.previous() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .help("Previous")

            // Play/Pause
            Button {
                Task { await coordinator.togglePlayPause() }
            } label: {
                Image(systemName: coordinator.transportInfo?.state.isPlaying == true ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }
            .buttonStyle(.plain)
            .help(coordinator.transportInfo?.state.isPlaying == true ? "Pause" : "Play")

            // Next
            Button {
                Task { await coordinator.next() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .help("Next")

            // Repeat
            Button {
                Task { await coordinator.toggleRepeat() }
            } label: {
                Image(systemName: coordinator.transportInfo?.playMode.isRepeatOne == true ? "repeat.1" : "repeat")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(coordinator.transportInfo?.playMode.isRepeating == true ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Repeat")
        }
    }
}
