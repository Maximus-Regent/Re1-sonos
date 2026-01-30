import SwiftUI
import MusicKit

/// Main Apple Music browsing view with tabs for Browse, Library, and Search.
struct AppleMusicBrowserView: View {
    @EnvironmentObject var coordinator: SonosCoordinator
    @StateObject private var musicService = AppleMusicService()
    @State private var selectedSection: MusicSection = .browse
    @State private var navigationPath: [MusicDestination] = []

    enum MusicSection: String, CaseIterable {
        case browse = "Browse"
        case library = "Library"
        case search = "Search"

        var icon: String {
            switch self {
            case .browse: return "square.grid.2x2"
            case .library: return "music.note.house"
            case .search: return "magnifyingglass"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if musicService.isAuthorized {
                // Section picker
                HStack(spacing: 0) {
                    ForEach(MusicSection.allCases, id: \.self) { section in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedSection = section
                                navigationPath.removeAll()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 12))
                                Text(section.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selectedSection == section ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .foregroundColor(selectedSection == section ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Back button when navigated
                    if !navigationPath.isEmpty {
                        Button {
                            withAnimation { navigationPath.removeLast() }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // Content
                if let destination = navigationPath.last {
                    destinationView(for: destination)
                } else {
                    switch selectedSection {
                    case .browse:
                        AppleMusicBrowseView(musicService: musicService, onNavigate: navigate)
                    case .library:
                        AppleMusicLibraryView(musicService: musicService, onNavigate: navigate)
                    case .search:
                        AppleMusicSearchView(musicService: musicService, onNavigate: navigate)
                    }
                }
            } else {
                authorizationView
            }
        }
        .environmentObject(musicService)
        .onAppear {
            musicService.checkAuthorization()
        }
    }

    private var authorizationView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "applelogo")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Apple Music")
                .font(.title2.bold())
            Text("Connect your Apple Music account to browse and play music on your Sonos speakers.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Authorize Apple Music") {
                Task { await musicService.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if musicService.authorizationStatus == .denied {
                Text("Access denied. Open System Settings > Privacy & Security > Media & Apple Music to grant access.")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            Spacer()
        }
        .padding(24)
    }

    private func navigate(to destination: MusicDestination) {
        withAnimation { navigationPath.append(destination) }
    }

    @ViewBuilder
    private func destinationView(for destination: MusicDestination) -> some View {
        switch destination {
        case .album(let album):
            AlbumDetailView(album: album, musicService: musicService)
        case .playlist(let playlist):
            PlaylistDetailView(playlist: playlist, musicService: musicService)
        case .artist(let artist):
            ArtistDetailView(artist: artist, musicService: musicService, onNavigate: navigate)
        }
    }
}

/// Navigation destinations for the Apple Music browser.
enum MusicDestination: Hashable {
    case album(Album)
    case playlist(Playlist)
    case artist(Artist)
}
