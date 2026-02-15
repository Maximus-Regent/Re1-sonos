import Foundation

enum AppleMusicItemType: String, Equatable {
    case song
    case album
    case artist
    case playlist
    case station
    case category
}

struct AppleMusicItem: Identifiable, Equatable {
    let id: String
    var title: String
    var subtitle: String
    var artworkURL: URL?
    var itemType: AppleMusicItemType
    var isContainer: Bool
    var musicKitID: String
}

struct AppleMusicBreadcrumb: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let itemType: AppleMusicItemType
    let musicKitID: String
}

enum AppleMusicCategory: String, CaseIterable, Identifiable {
    case topCharts = "Top Charts"
    case newMusic = "New Music"
    case playlists = "Playlists"
    case genres = "Genres"
    case recommendations = "For You"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .topCharts: return "chart.bar"
        case .newMusic: return "sparkles"
        case .playlists: return "music.note.list"
        case .genres: return "guitars"
        case .recommendations: return "person.crop.square"
        }
    }
}
