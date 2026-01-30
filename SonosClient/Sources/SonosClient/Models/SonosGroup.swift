import Foundation

/// Represents a Sonos zone group (one coordinator + optional satellite speakers).
struct SonosGroup: Identifiable, Hashable {
    var id: String { coordinator.id }
    var coordinator: SonosDevice
    var members: [SonosDevice]
    var volume: Int
    var muted: Bool

    var displayName: String {
        if members.count <= 1 {
            return coordinator.roomName
        }
        let names = ([coordinator] + members.filter { $0.id != coordinator.id })
            .map(\.roomName)
        return names.joined(separator: " + ")
    }

    static func == (lhs: SonosGroup, rhs: SonosGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
