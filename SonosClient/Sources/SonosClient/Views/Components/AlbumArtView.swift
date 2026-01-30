import SwiftUI

/// Displays album art with fallback placeholder.
struct AlbumArtView: View {
    let track: Track
    let baseURL: URL?
    var size: CGFloat = 200

    var body: some View {
        Group {
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                            .overlay(
                                ProgressView()
                                    .controlSize(.small)
                            )
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size > 100 ? 12 : 6))
        .shadow(color: .black.opacity(0.2), radius: size > 100 ? 16 : 4, x: 0, y: size > 100 ? 8 : 2)
    }

    private var resolvedURL: URL? {
        guard let base = baseURL else { return nil }
        return track.albumArtURL(relativeTo: base)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .controlAccentColor).opacity(0.3),
                    Color(nsColor: .controlAccentColor).opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.3))
                .foregroundColor(.secondary.opacity(0.4))
        }
    }
}
