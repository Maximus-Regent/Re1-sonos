import SwiftUI

/// Main application layout: sidebar + detail area with now-playing bar at the bottom.
struct ContentView: View {
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var selectedTab: SidebarTab = .nowPlaying
    @State private var sidebarWidth: CGFloat = 240

    enum SidebarTab: String, CaseIterable {
        case nowPlaying = "Now Playing"
        case queue = "Queue"
        case rooms = "Rooms"

        var icon: String {
            switch self {
            case .nowPlaying: return "music.note"
            case .queue: return "list.bullet"
            case .rooms: return "house.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            HStack(spacing: 0) {
                // Sidebar
                sidebarView
                    .frame(width: sidebarWidth)

                Divider()

                // Detail area
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            // Bottom now-playing bar
            NowPlayingBar()
                .frame(height: 80)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Error", isPresented: .init(
            get: { coordinator.errorMessage != nil },
            set: { if !$0 { coordinator.errorMessage = nil } }
        )) {
            Button("OK") { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Tab selector
            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 20)
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ?
                                      Color.accentColor.opacity(0.15) :
                                        Color.clear)
                        )
                        .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)

            Divider()
                .padding(.vertical, 8)

            // Room/group list
            RoomListSidebar()

            Spacer()

            // Discovery status
            if coordinator.isDiscovering {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Discovering...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .nowPlaying:
            NowPlayingDetailView()
        case .queue:
            QueueView()
        case .rooms:
            RoomManagementView()
        }
    }
}
