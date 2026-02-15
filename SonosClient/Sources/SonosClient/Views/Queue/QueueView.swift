import SwiftUI

/// Displays the current playback queue for the selected group.
struct QueueView: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Queue")
                        .font(.system(size: 20, weight: .semibold))
                    if let group = coordinator.selectedGroup {
                        Text(group.displayName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("\(coordinator.queue.count) tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        Task { await coordinator.refreshQueue() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if !coordinator.queue.isEmpty {
                        Button("Clear") {
                            Task { await coordinator.clearQueue() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Queue List
            if coordinator.queue.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Queue is empty")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(Array(coordinator.queue.enumerated()), id: \.element.id) { index, track in
                        QueueTrackRow(
                            track: track,
                            trackNumber: index + 1,
                            isCurrentTrack: isCurrentTrack(index + 1),
                            baseURL: coordinator.selectedGroup?.coordinator.baseURL
                        )
                        .onTapGesture(count: 2) {
                            Task { await coordinator.playTrackFromQueue(trackNumber: index + 1) }
                        }
                        .contextMenu {
                            Button("Play") {
                                Task { await coordinator.playTrackFromQueue(trackNumber: index + 1) }
                            }
                            Divider()
                            Button("Remove from Queue") {
                                Task { await coordinator.removeFromQueue(trackNumber: index + 1) }
                            }
                        }
                        .listRowSeparator(.visible)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    }
                    .onMove { source, destination in
                        coordinator.moveQueueTrack(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func isCurrentTrack(_ number: Int) -> Bool {
        coordinator.transportInfo?.currentTrackNumber == number
    }
}

struct QueueTrackRow: View {
    let track: Track
    let trackNumber: Int
    let isCurrentTrack: Bool
    let baseURL: URL?

    var body: some View {
        HStack(spacing: 10) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.4))

            // Track number or playing indicator
            ZStack {
                if isCurrentTrack {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                } else {
                    Text("\(trackNumber)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 28, alignment: .center)

            // Mini album art
            if let resolvedBase = baseURL ?? URL(string: "http://localhost"),
               let url = track.albumArtURL(relativeTo: resolvedBase) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.3))
                    )
            }

            // Track info
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.system(size: 13, weight: isCurrentTrack ? .semibold : .regular))
                    .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Album name
            Text(track.album)
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isCurrentTrack ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
