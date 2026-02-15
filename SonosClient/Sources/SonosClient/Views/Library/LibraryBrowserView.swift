import SwiftUI

/// Music library browser with category grid and drill-down navigation.
struct LibraryBrowserView: View {
    @EnvironmentObject var coordinator: SonosCoordinator

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Music Library")
                        .font(.system(size: 20, weight: .semibold))
                    if let group = coordinator.selectedGroup {
                        Text(group.displayName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            if coordinator.libraryPath.isEmpty {
                // Category grid
                categoriesGrid
            } else {
                // Breadcrumbs + item list
                VStack(spacing: 0) {
                    breadcrumbBar
                    Divider()
                    itemList
                }
            }
        }
    }

    // MARK: - Categories Grid

    private var categoriesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)
            ], spacing: 12) {
                ForEach(LibrarySection.allCases) { section in
                    Button {
                        coordinator.browseLibrary(section: section)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: section.icon)
                                .font(.system(size: 28))
                                .foregroundColor(.accentColor)
                            Text(section.displayName)
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

    // MARK: - Breadcrumbs

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    coordinator.browseLibrary()
                } label: {
                    Image(systemName: "music.note.house")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                ForEach(coordinator.libraryPath) { crumb in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Button(crumb.title) {
                        coordinator.navigateLibraryTo(crumb)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: crumb.id == coordinator.libraryPath.last?.id ? .semibold : .regular))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Item List

    private var itemList: some View {
        Group {
            if coordinator.libraryItems.isEmpty && coordinator.isLoadingLibrary {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if coordinator.libraryItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No items found")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    // Action bar
                    HStack {
                        Text("\(coordinator.libraryTotalMatches) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()

                        Button {
                            Task { await coordinator.playAllLibraryItems() }
                        } label: {
                            Label("Play All", systemImage: "play.fill")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(coordinator.libraryItems) { item in
                                LibraryItemRow(
                                    item: item,
                                    baseURL: coordinator.selectedGroup?.coordinator.baseURL
                                )
                                .onTapGesture {
                                    if item.isContainer {
                                        coordinator.browseContainer(item)
                                    }
                                }
                                .onTapGesture(count: 2) {
                                    if !item.isContainer {
                                        Task { await coordinator.addLibraryItemToQueue(item) }
                                    }
                                }
                                .contextMenu {
                                    Button("Add to Queue") {
                                        Task { await coordinator.addLibraryItemToQueue(item) }
                                    }
                                    if item.isContainer {
                                        Button("Browse") {
                                            coordinator.browseContainer(item)
                                        }
                                    }
                                }

                                Divider().padding(.leading, 58)
                            }

                            // Load more
                            if coordinator.libraryItems.count < coordinator.libraryTotalMatches {
                                Button("Load More") {
                                    coordinator.loadMoreLibraryItems()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .padding(12)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
    }
}
