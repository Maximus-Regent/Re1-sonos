import SwiftUI

/// Row view for Apple Music items, using URL-based artwork.
struct AppleMusicItemRow: View {
    let item: AppleMusicItem

    var body: some View {
        HStack(spacing: 10) {
            // Artwork
            if let url = item.artworkURL {
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
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Type indicator
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
                Image(systemName: iconForType)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.3))
            )
    }

    private var iconForType: String {
        switch item.itemType {
        case .song: return "music.note"
        case .album: return "square.stack"
        case .artist: return "person"
        case .playlist: return "music.note.list"
        case .station: return "antenna.radiowaves.left.and.right"
        case .category: return "square.grid.2x2"
        }
    }
}
