import Foundation

/// The playback state of a Sonos zone.
enum PlaybackState: String {
    case playing = "PLAYING"
    case paused = "PAUSED_PLAYBACK"
    case stopped = "STOPPED"
    case transitioning = "TRANSITIONING"

    var isPlaying: Bool { self == .playing }
}

/// Repeat/shuffle modes.
enum PlayMode: String {
    case normal = "NORMAL"
    case repeatAll = "REPEAT_ALL"
    case repeatOne = "REPEAT_ONE"
    case shuffle = "SHUFFLE"
    case shuffleRepeat = "SHUFFLE_REPEAT_ALL"
    case shuffleNoRepeat = "SHUFFLE_NOREPEAT"

    var isShuffled: Bool {
        switch self {
        case .shuffle, .shuffleRepeat, .shuffleNoRepeat: return true
        default: return false
        }
    }

    var isRepeating: Bool {
        switch self {
        case .repeatAll, .repeatOne, .shuffleRepeat: return true
        default: return false
        }
    }

    var isRepeatOne: Bool { self == .repeatOne }
}

/// Full transport info for a zone.
struct TransportInfo {
    var state: PlaybackState
    var currentTrack: Track
    var nextTrack: Track?
    var playMode: PlayMode
    var currentPosition: TimeInterval
    var numberOfTracks: Int
    var currentTrackNumber: Int
}
