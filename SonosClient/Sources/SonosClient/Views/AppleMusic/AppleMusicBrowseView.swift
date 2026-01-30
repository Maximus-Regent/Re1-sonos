import SwiftUI
import MusicKit

/// Browse section: shows recommendations, charts, and recently played.
struct AppleMusicBrowseView: View {
    let musicService: AppleMusicService
    let onNavigate: (MusicDestination) -> Void

    @State private var charts: MusicChartsResponse?
    @State private var isLoading = true
    @State private var errorMsg: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = errorMsg {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") { Task { await loadContent() } }
                            .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Recently Played
                    if let recent = musicService.recentlyPlayed, !recent.isEmpty {
                        sectionHeader("Recently Played")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recent, id: \.id) { item in
                                    RecentlyPlayedCard(item: item, onNavigate: onNavigate)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Recommendations
                    if !musicService.recommendations.isEmpty {
                        ForEach(musicService.recommendations, id: \.id) { rec in
                            if let title = rec.title {
                                sectionHeader(title)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // Albums
                                    if let albums = rec.albums {
                                        ForEach(albums, id: \.id) { album in
                                            AlbumCard(album: album) {
                                                onNavigate(.album(album))
                                            }
                                        }
                                    }
                                    // Playlists
                                    if let playlists = rec.playlists {
                                        ForEach(playlists, id: \.id) { playlist in
                                            PlaylistCard(playlist: playlist) {
                                                onNavigate(.playlist(playlist))
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    // Top Songs Chart
                    if let songCharts = charts?.songCharts, let topChart = songCharts.first {
                        sectionHeader(topChart.title)
                        VStack(spacing: 0) {
                            ForEach(Array(topChart.items.prefix(20).enumerated()), id: \.element.id) { index, song in
                                SongRow(song: song, index: index + 1, onNavigate: onNavigate)
                                if index < min(19, topChart.items.count - 1) {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Top Albums Chart
                    if let albumCharts = charts?.albumCharts, let topChart = albumCharts.first {
                        sectionHeader(topChart.title)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(topChart.items, id: \.id) { album in
                                    AlbumCard(album: album) {
                                        onNavigate(.album(album))
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .task { await loadContent() }
    }

    private func loadContent() async {
        isLoading = true
        errorMsg = nil
        do {
            async let _ = musicService.fetchRecentlyPlayed()
            async let _ = musicService.fetchRecommendations()
            charts = try await musicService.fetchCharts()
            // Wait for the others (errors are non-fatal)
            try? await musicService.fetchRecentlyPlayed()
            try? await musicService.fetchRecommendations()
            isLoading = false
        } catch {
            errorMsg = error.localizedDescription
            isLoading = false
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .padding(.horizontal, 20)
    }
}

// MARK: - Recently Played Card

struct RecentlyPlayedCard: View {
    let item: RecentlyPlayedMusicItem
    let onNavigate: (MusicDestination) -> Void

    var body: some View {
        Button {
            // Try to navigate based on type
            if case let .album(album) = item {
                onNavigate(.album(album))
            } else if case let .playlist(playlist) = item {
                onNavigate(.playlist(playlist))
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                artworkView
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(itemTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(itemSubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var artworkView: some View {
        if case let .album(album) = item, let artwork = album.artwork {
            ArtworkImage(artwork, width: 140, height: 140)
        } else if case let .playlist(playlist) = item, let artwork = playlist.artwork {
            ArtworkImage(artwork, width: 140, height: 140)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundColor(.secondary.opacity(0.3))
                )
        }
    }

    private var itemTitle: String {
        switch item {
        case .album(let a): return a.title
        case .playlist(let p): return p.name
        case .station(let s): return s.name
        @unknown default: return "Unknown"
        }
    }

    private var itemSubtitle: String {
        switch item {
        case .album(let a): return a.artistName
        case .playlist(let p): return p.curatorName ?? ""
        case .station: return "Station"
        @unknown default: return ""
        }
    }
}
