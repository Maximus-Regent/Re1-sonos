import SwiftUI

/// Reusable row for displaying a browsable library item.
struct LibraryItemRow: View {
    let item: BrowsableItem
    let baseURL: URL?

    var body: some View {
        HStack(spacing: 10) {
            // Album art or icon
            if let resolvedBase = baseURL ?? URL(string: "http://localhost"),
               let url = item.albumArtURL(relativeTo: resolvedBase) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderView
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                placeholderView
                    .frame(width: 40, height: 40)
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if !item.artist.isEmpty {
                    Text(item.artist)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if !item.album.isEmpty {
                    Text(item.album)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.isContainer {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.1))
            .overlay(
                Image(systemName: item.isContainer ? "folder.fill" : "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.3))
            )
    }
}
