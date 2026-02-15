import Foundation

/// Controls playback on a Sonos zone (play, pause, skip, seek, etc.)
actor TransportService {
    private let soap = SOAPClient()

    // MARK: - Playback Control

    func play(device: SonosDevice) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "Play",
                                arguments: [("Speed", "1")])
    }

    func pause(device: SonosDevice) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "Pause")
    }

    func stop(device: SonosDevice) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "Stop")
    }

    func next(device: SonosDevice) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "Next")
    }

    func previous(device: SonosDevice) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "Previous")
    }

    func seek(device: SonosDevice, to time: TimeInterval) async throws {
        let h = Int(time) / 3600
        let m = (Int(time) % 3600) / 60
        let s = Int(time) % 60
        let target = String(format: "%d:%02d:%02d", h, m, s)
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "Seek",
                                arguments: [("Unit", "REL_TIME"), ("Target", target)])
    }

    func seekTrack(device: SonosDevice, trackNumber: Int) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "Seek",
                                arguments: [("Unit", "TRACK_NR"), ("Target", "\(trackNumber)")])
    }

    // MARK: - Play Mode

    func setPlayMode(device: SonosDevice, mode: PlayMode) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "SetPlayMode",
                                arguments: [("NewPlayMode", mode.rawValue)])
    }

    // MARK: - Transport Info

    func getTransportInfo(device: SonosDevice) async throws -> TransportInfo {
        async let positionResponse = soap.send(to: device.baseURL, service: .avTransport, action: "GetPositionInfo")
        async let transportResponse = soap.send(to: device.baseURL, service: .avTransport, action: "GetTransportInfo")
        async let settingsResponse = soap.send(to: device.baseURL, service: .avTransport, action: "GetTransportSettings")

        let posXML = try await positionResponse
        let transXML = try await transportResponse
        let settingsXML = try await settingsResponse

        // Parse transport state
        let stateStr = XMLHelper.extractValue(tag: "CurrentTransportState", from: transXML) ?? "STOPPED"
        let state = PlaybackState(rawValue: stateStr) ?? .stopped

        // Parse position info
        let trackURI = XMLHelper.extractValue(tag: "TrackURI", from: posXML) ?? ""
        let trackMetaData = XMLHelper.extractValue(tag: "TrackMetaData", from: posXML) ?? ""
        let durationStr = XMLHelper.extractValue(tag: "TrackDuration", from: posXML) ?? "0:00:00"
        let relTimeStr = XMLHelper.extractValue(tag: "RelTime", from: posXML) ?? "0:00:00"
        let trackNumStr = XMLHelper.extractValue(tag: "Track", from: posXML) ?? "0"
        let numTracksStr = XMLHelper.extractValue(tag: "NrTracks", from: posXML) ?? "0"

        var track = XMLHelper.parseTrackMetadata(trackMetaData, trackURI: trackURI) ?? .empty
        track.duration = XMLHelper.parseDuration(durationStr)

        let position = XMLHelper.parseDuration(relTimeStr)

        // Parse play mode
        let playModeStr = XMLHelper.extractValue(tag: "PlayMode", from: settingsXML) ?? "NORMAL"
        let playMode = PlayMode(rawValue: playModeStr) ?? .normal

        return TransportInfo(
            state: state,
            currentTrack: track,
            nextTrack: nil,
            playMode: playMode,
            currentPosition: position,
            numberOfTracks: Int(numTracksStr) ?? 0,
            currentTrackNumber: Int(trackNumStr) ?? 0
        )
    }

    // MARK: - Queue

    func getQueue(device: SonosDevice, start: Int = 0, count: Int = 100) async throws -> [Track] {
        let response = try await soap.send(
            to: device.baseURL,
            service: .contentDirectory,
            action: "Browse",
            arguments: [
                ("ObjectID", "Q:0"),
                ("BrowseFlag", "BrowseDirectChildren"),
                ("Filter", "dc:title,res,dc:creator,upnp:albumArtURI,upnp:album,upnp:originalTrackNumber"),
                ("StartingIndex", "\(start)"),
                ("RequestedCount", "\(count)"),
                ("SortCriteria", "")
            ]
        )

        guard let result = XMLHelper.extractValue(tag: "Result", from: response) else {
            return []
        }

        let decoded = result
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")

        // Split by <item and parse each
        let items = decoded.components(separatedBy: "<item ")
        var tracks: [Track] = []

        for (index, item) in items.enumerated() where index > 0 {
            let title = XMLHelper.extractValue(tag: "dc:title", from: item) ?? "Unknown"
            let artist = XMLHelper.extractValue(tag: "dc:creator", from: item) ?? ""
            let album = XMLHelper.extractValue(tag: "upnp:album", from: item) ?? ""
            let albumArt = XMLHelper.extractValue(tag: "upnp:albumArtURI", from: item) ?? ""
            let trackNumStr = XMLHelper.extractValue(tag: "upnp:originalTrackNumber", from: item) ?? "\(index)"

            // Extract URI from res tag
            var uri = ""
            if let resStart = item.range(of: "<res "),
               let resClose = item.range(of: ">", range: resStart.upperBound..<item.endIndex),
               let resEnd = item.range(of: "</res>", range: resClose.upperBound..<item.endIndex) {
                uri = String(item[resClose.upperBound..<resEnd.lowerBound])
            }

            tracks.append(Track(
                id: "\(start + index)",
                title: title,
                artist: artist,
                album: album,
                albumArtURI: albumArt,
                duration: 0,
                uri: uri,
                trackNumber: Int(trackNumStr) ?? index
            ))
        }

        return tracks
    }

    // MARK: - URI Playback

    func setAVTransportURI(device: SonosDevice, uri: String, metadata: String = "") async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "SetAVTransportURI",
                                arguments: [("CurrentURI", uri), ("CurrentURIMetaData", metadata)])
    }

    func addURIToQueue(device: SonosDevice, uri: String, metadata: String = "", position: Int = 0) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "AddURIToQueue",
                                arguments: [
                                    ("EnqueuedURI", uri),
                                    ("EnqueuedURIMetaData", metadata),
                                    ("DesiredFirstTrackNumberEnqueued", "\(position)"),
                                    ("EnqueueAsNext", position == 0 ? "0" : "1")
                                ])
    }

    func removeAllTracksFromQueue(device: SonosDevice) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "RemoveAllTracksFromQueue")
    }

    func removeTrackFromQueue(device: SonosDevice, trackNumber: Int) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "RemoveTrackFromQueue",
                                arguments: [("ObjectID", "Q:0/\(trackNumber)")])
    }

    // MARK: - Sleep Timer

    func configureSleepTimer(device: SonosDevice, duration: String) async throws {
        // duration format: "HH:MM:SS" or "" to cancel
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "ConfigureSleepTimer",
                                arguments: [("NewSleepTimerDuration", duration)])
    }

    func getSleepTimerDuration(device: SonosDevice) async throws -> String {
        let response = try await soap.send(to: device.baseURL, service: .avTransport, action: "GetRemainingSleepTimerDuration")
        return XMLHelper.extractValue(tag: "RemainingSleepTimerDuration", from: response) ?? ""
    }

    // MARK: - Crossfade

    func getCrossfadeMode(device: SonosDevice) async throws -> Bool {
        let response = try await soap.send(to: device.baseURL, service: .avTransport, action: "GetCrossfadeMode")
        return XMLHelper.extractValue(tag: "CrossfadeMode", from: response) == "1"
    }

    func setCrossfadeMode(device: SonosDevice, enabled: Bool) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "SetCrossfadeMode",
                                arguments: [("CrossfadeMode", enabled ? "1" : "0")])
    }

    // MARK: - Queue Reorder

    func reorderTracksInQueue(device: SonosDevice, startingIndex: Int, numberOfTracks: Int, insertBefore: Int) async throws {
        _ = try await soap.send(to: device.baseURL, service: .avTransport, action: "ReorderTracksInQueue",
                                arguments: [
                                    ("StartingIndex", "\(startingIndex)"),
                                    ("NumberOfTracks", "\(numberOfTracks)"),
                                    ("InsertBefore", "\(insertBefore)"),
                                    ("UpdateID", "0")
                                ])
    }
}
