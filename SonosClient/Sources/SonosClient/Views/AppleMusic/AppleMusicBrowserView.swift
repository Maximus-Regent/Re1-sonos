import SwiftUI

/// Browse and search the Apple Music catalog. Follows the LibraryBrowserView pattern:
/// category grid → breadcrumb drill-down → item list.
struct AppleMusicBrowserView: View {
    @EnvironmentObject var coordinator: SonosCoordinator
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Music")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Browse and search the catalog")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            if !coordinator.appleMusicAuthorized {
                authPrompt
                    .onAppear {
                        coordinator.checkAppleMusicAuth()
                    }
            } else {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search Apple Music...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            coordinator.searchAppleMusic(query: searchText)
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            coordinator.searchAppleMusic(query: "")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.06))

                Divider()

                // Content
                if coordinator.appleMusicPath.isEmpty && coordinator.appleMusicSearchQuery.isEmpty {
                    categoriesGrid
                } else {
                    VStack(spacing: 0) {
                        if !coordinator.appleMusicPath.isEmpty {
                            breadcrumbBar
                            Divider()
                        }
                        itemList
                    }
                }
            }
        }
    }

    // MARK: - Auth Prompt

    private var authPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "apple.logo")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Apple Music Access Required")
                .font(.system(size: 16, weight: .semibold))
            Text("Grant access to browse and play from the Apple Music catalog.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Authorize Apple Music") {
                coordinator.requestAppleMusicAuth()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding(40)
    }

    // MARK: - Categories Grid

    private var categoriesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)
            ], spacing: 12) {
                ForEach(AppleMusicCategory.allCases) { category in
                    Button {
                        coordinator.browseAppleMusic(category: category)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 28))
                                .foregroundColor(.accentColor)
                            Text(category.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Breadcrumb Bar

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    coordinator.appleMusicPath = []
                    coordinator.appleMusicItems = []
                    coordinator.appleMusicTotalMatches = 0
                    coordinator.appleMusicSearchQuery = ""
                    searchText = ""
                } label: {
                    Image(systemName: "music.note.house")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                ForEach(coordinator.appleMusicPath) { crumb in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Button(crumb.title) {
                        coordinator.navigateAppleMusicTo(crumb)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: crumb.id == coordinator.appleMusicPath.last?.id ? .semibold : .regular))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Item List

    private var itemList: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                Text("\(coordinator.appleMusicTotalMatches) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                if coordinator.isLoadingAppleMusic {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Divider()

            if coordinator.isLoadingAppleMusic && coordinator.appleMusicItems.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
            } else if coordinator.appleMusicItems.isEmpty {
                VStack {
                    Spacer()
                    Text("No results")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(coordinator.appleMusicItems) { item in
                            AppleMusicItemRow(item: item)
                                .onTapGesture {
                                    if item.isContainer {
                                        coordinator.browseAppleMusicContainer(item)
                                    } else {
                                        coordinator.playAppleMusicItem(item)
                                    }
                                }
                                .contextMenu {
                                    Button("Play") {
                                        coordinator.playAppleMusicItem(item)
                                    }
                                    if item.isContainer {
                                        Button("Browse") {
                                            coordinator.browseAppleMusicContainer(item)
                                        }
                                    }
                                }

                            Divider()
                                .padding(.leading, 58)
                        }
                    }
                }
            }
        }
    }
}
