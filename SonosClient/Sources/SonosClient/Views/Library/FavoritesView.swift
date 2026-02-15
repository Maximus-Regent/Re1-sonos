import SwiftUI

/// Favorites & playlists view with segmented picker.
struct FavoritesView: View {
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var selectedSegment: Segment = .favorites

    enum Segment: String, CaseIterable {
        case favorites = "Favorites"
        case playlists = "Playlists"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorites & Playlists")
                        .font(.system(size: 20, weight: .semibold))
                    if let group = coordinator.selectedGroup {
                        Text(group.displayName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                Button {
                    Task {
                        await coordinator.refreshFavorites()
                        await coordinator.refreshPlaylists()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Segmented Picker
            Picker("", selection: $selectedSegment) {
                ForEach(Segment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Divider()

            // Content
            let items = selectedSegment == .favorites ? coordinator.favorites : coordinator.playlists

            if items.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: selectedSegment == .favorites ? "star" : "music.note.list")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(selectedSegment == .favorites ? "No favorites" : "No playlists")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("Load items from your Sonos system")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            LibraryItemRow(
                                item: item,
                                baseURL: coordinator.selectedGroup?.coordinator.baseURL
                            )
                            .onTapGesture(count: 2) {
                                Task { await coordinator.playFavoriteOrPlaylist(item) }
                            }
                            .contextMenu {
                                Button("Play") {
                                    Task { await coordinator.playFavoriteOrPlaylist(item) }
                                }
                                Button("Add to Queue") {
                                    Task { await coordinator.addLibraryItemToQueue(item) }
                                }
                            }

                            Divider().padding(.leading, 58)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .onAppear {
            Task {
                await coordinator.refreshFavorites()
                await coordinator.refreshPlaylists()
            }
        }
    }
}
