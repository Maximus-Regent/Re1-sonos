import Foundation
import Combine
import MusicKit

/// Central coordinator that manages device discovery, state polling, and exposes
/// reactive state for the SwiftUI views.
@MainActor
final class SonosCoordinator: ObservableObject {
    // MARK: - Published State

    @Published var devices: [SonosDevice] = []
    @Published var groups: [SonosGroup] = []
    @Published var selectedGroup: SonosGroup?
    @Published var transportInfo: TransportInfo?
    @Published var queue: [Track] = []
    @Published var volume: Int = 0
    @Published var isMuted: Bool = false
    @Published var isDiscovering: Bool = false
    @Published var errorMessage: String?

    // EQ
    @Published var bass: Int = 0
    @Published var treble: Int = 0

    // Sleep Timer
    @Published var sleepTimerRemaining: TimeInterval?

    // Crossfade
    @Published var isCrossfadeEnabled: Bool = false

    // Music Library
    @Published var libraryItems: [BrowsableItem] = []
    @Published var libraryPath: [LibraryBreadcrumb] = []
    @Published var libraryTotalMatches: Int = 0
    @Published var isLoadingLibrary: Bool = false

    // Favorites & Playlists
    @Published var favorites: [BrowsableItem] = []
    @Published var playlists: [BrowsableItem] = []

    // Apple Music
    @Published var appleMusicAuthorized: Bool = false
    @Published var appleMusicItems: [AppleMusicItem] = []
    @Published var appleMusicPath: [AppleMusicBreadcrumb] = []
    @Published var appleMusicTotalMatches: Int = 0
    @Published var isLoadingAppleMusic: Bool = false
    @Published var appleMusicSearchQuery: String = ""
    @Published var isAppleMusicPlaying: Bool = false

    // Input Source
    enum InputSource: String, CaseIterable {
        case queue = "Queue"
        case lineIn = "Line-In"
        case tvInput = "TV"
    }
    @Published var currentInputSource: InputSource = .queue

    // MARK: - Services

    private let discovery = SSDPDiscovery()
    private let transport = TransportService()
    private let rendering = RenderingService()
    private let zoneService = ZoneService()
    private let libraryService = MusicLibraryService()
    private let appleMusicService = AppleMusicService()

    // MARK: - State

    private var knownDeviceIPs: Set<String> = []
    private var knownDevices: [String: SonosDevice] = [:] // id -> device
    private var pollingTimer: Timer?
    private var positionTimer: Timer?
    private var sleepTimerCountdown: Timer?

    // MARK: - Lifecycle

    init() {
        // Check current Apple Music authorization status on launch
        appleMusicAuthorized = (MusicAuthorization.currentStatus == .authorized)
    }

    func startDiscovery() {
        isDiscovering = true
        knownDeviceIPs.removeAll()

        discovery.search { [weak self] ip, port in
            Task { @MainActor [weak self] in
                await self?.handleDiscoveredDevice(ip: ip, port: port)
            }
        }

        // Stop discovery after a timeout and refresh groups
        Task {
            try? await Task.sleep(for: .seconds(5))
            discovery.stop()
            isDiscovering = false
            await refreshGroups()
            startPolling()
        }
    }

    func stopAll() {
        discovery.stop()
        pollingTimer?.invalidate()
        positionTimer?.invalidate()
        sleepTimerCountdown?.invalidate()
        pollingTimer = nil
        positionTimer = nil
        sleepTimerCountdown = nil
    }

    // MARK: - Discovery

    private func handleDiscoveredDevice(ip: String, port: Int) async {
        guard !knownDeviceIPs.contains(ip) else { return }
        knownDeviceIPs.insert(ip)

        do {
            guard let device = try await DeviceDescriptionFetcher.fetch(ip: ip, port: port) else { return }
            knownDevices[device.id] = device
            if !devices.contains(where: { $0.id == device.id }) {
                devices.append(device)
            }
        } catch {
            print("[Discovery] Failed to fetch device at \(ip): \(error)")
        }
    }

    // MARK: - Groups

    func refreshGroups() async {
        guard let anyDevice = devices.first else { return }
        do {
            let xml = try await zoneService.getZoneGroupState(device: anyDevice)
            let parsed = await zoneService.parseZoneGroups(from: xml, knownDevices: knownDevices)
            groups = parsed

            // Update group volumes
            for i in groups.indices {
                if let vol = try? await rendering.getGroupVolume(device: groups[i].coordinator) {
                    groups[i].volume = vol
                }
            }

            // Auto-select first group if none selected
            if selectedGroup == nil, let first = groups.first {
                selectGroup(first)
            } else if let sel = selectedGroup,
                      let updated = groups.first(where: { $0.id == sel.id }) {
                selectedGroup = updated
            }
        } catch {
            errorMessage = "Failed to fetch zone groups: \(error.localizedDescription)"
        }
    }

    func selectGroup(_ group: SonosGroup) {
        selectedGroup = group
        Task {
            await refreshTransport()
            await refreshQueue()
            await refreshVolume()
            await refreshEQ()
            await refreshCrossfade()
            await refreshSleepTimer()
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTimer?.invalidate()
        positionTimer?.invalidate()

        // Poll transport state every 3 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshTransport()
            }
        }

        // Update position every second for smooth progress bar
        // Capture the last known server position and use elapsed time for accuracy
        var lastServerSync = Date()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, var info = self.transportInfo, info.state == .playing else { return }
                let now = Date()
                let elapsed = now.timeIntervalSince(lastServerSync)
                lastServerSync = now
                info.currentPosition += elapsed
                self.transportInfo = info
            }
        }
    }

    // MARK: - Transport

    func refreshTransport() async {
        guard let group = selectedGroup else { return }
        do {
            let info = try await transport.getTransportInfo(device: group.coordinator)
            transportInfo = info
            // Detect input source from current URI
            let uri = info.currentTrack.uri
            if uri.hasPrefix("x-sonos-htastream:") {
                currentInputSource = .tvInput
            } else if uri.hasPrefix("x-rincon-stream:") {
                currentInputSource = .lineIn
            } else {
                currentInputSource = .queue
            }
        } catch {
            // Silently ignore polling errors
        }
    }

    func play() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.play(device: group.coordinator)
            transportInfo?.state = .playing
        } catch {
            errorMessage = "Play failed: \(error.localizedDescription)"
        }
    }

    func pause() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.pause(device: group.coordinator)
            transportInfo?.state = .paused
        } catch {
            errorMessage = "Pause failed: \(error.localizedDescription)"
        }
    }

    func togglePlayPause() async {
        if transportInfo?.state.isPlaying == true {
            await pause()
        } else {
            await play()
        }
    }

    func next() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.next(device: group.coordinator)
            try? await Task.sleep(for: .milliseconds(300))
            await refreshTransport()
        } catch {
            errorMessage = "Next failed: \(error.localizedDescription)"
        }
    }

    func previous() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.previous(device: group.coordinator)
            try? await Task.sleep(for: .milliseconds(300))
            await refreshTransport()
        } catch {
            errorMessage = "Previous failed: \(error.localizedDescription)"
        }
    }

    func seek(to position: TimeInterval) async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.seek(device: group.coordinator, to: position)
            transportInfo?.currentPosition = position
        } catch {
            errorMessage = "Seek failed: \(error.localizedDescription)"
        }
    }

    func playTrackFromQueue(trackNumber: Int) async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.seekTrack(device: group.coordinator, trackNumber: trackNumber)
            try await transport.play(device: group.coordinator)
            try? await Task.sleep(for: .milliseconds(300))
            await refreshTransport()
        } catch {
            errorMessage = "Play track failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Play Mode

    func toggleShuffle() async {
        guard let group = selectedGroup, let info = transportInfo else { return }
        let newMode: PlayMode
        switch info.playMode {
        case .normal: newMode = .shuffle
        case .shuffle, .shuffleNoRepeat: newMode = .normal
        case .repeatAll: newMode = .shuffleRepeat
        case .shuffleRepeat: newMode = .repeatAll
        case .repeatOne: newMode = .shuffle
        }
        do {
            try await transport.setPlayMode(device: group.coordinator, mode: newMode)
            transportInfo?.playMode = newMode
        } catch {
            errorMessage = "Shuffle toggle failed: \(error.localizedDescription)"
        }
    }

    func toggleRepeat() async {
        guard let group = selectedGroup, let info = transportInfo else { return }
        let newMode: PlayMode
        switch info.playMode {
        case .normal: newMode = .repeatAll
        case .repeatAll: newMode = .repeatOne
        case .repeatOne: newMode = .normal
        case .shuffle, .shuffleNoRepeat: newMode = .shuffleRepeat
        case .shuffleRepeat: newMode = .shuffle
        }
        do {
            try await transport.setPlayMode(device: group.coordinator, mode: newMode)
            transportInfo?.playMode = newMode
        } catch {
            errorMessage = "Repeat toggle failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Volume

    func refreshVolume() async {
        guard let group = selectedGroup else { return }
        do {
            volume = try await rendering.getGroupVolume(device: group.coordinator)
            isMuted = false // Will be updated via events in future
        } catch {
            // Silently ignore
        }
    }

    func setVolume(_ newVolume: Int) async {
        guard let group = selectedGroup else { return }
        volume = newVolume
        do {
            try await rendering.setGroupVolume(device: group.coordinator, volume: newVolume)
        } catch {
            errorMessage = "Volume failed: \(error.localizedDescription)"
        }
    }

    func toggleMute() async {
        guard let group = selectedGroup else { return }
        isMuted.toggle()
        do {
            try await rendering.setGroupMute(device: group.coordinator, muted: isMuted)
        } catch {
            errorMessage = "Mute toggle failed: \(error.localizedDescription)"
        }
    }

    func setDeviceVolume(_ device: SonosDevice, volume: Int) async {
        do {
            try await rendering.setVolume(device: device, volume: volume)
        } catch {
            errorMessage = "Device volume failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Queue

    func refreshQueue() async {
        guard let group = selectedGroup else { return }
        do {
            queue = try await transport.getQueue(device: group.coordinator)
        } catch {
            errorMessage = "Queue fetch failed: \(error.localizedDescription)"
        }
    }

    func clearQueue() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.removeAllTracksFromQueue(device: group.coordinator)
            queue.removeAll()
        } catch {
            errorMessage = "Clear queue failed: \(error.localizedDescription)"
        }
    }

    func removeFromQueue(trackNumber: Int) async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.removeTrackFromQueue(device: group.coordinator, trackNumber: trackNumber)
            await refreshQueue()
        } catch {
            errorMessage = "Remove track failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Queue Reorder

    func moveQueueTrack(from source: IndexSet, to destination: Int) {
        guard let group = selectedGroup else { return }
        guard let sourceIndex = source.first else { return }

        // Optimistic local update
        queue.move(fromOffsets: source, toOffset: destination)

        // Sonos uses 1-based track numbers; insertBefore uses original positions
        let sonosSource = sourceIndex + 1
        let sonosDest = destination + 1

        Task {
            do {
                try await transport.reorderTracksInQueue(
                    device: group.coordinator,
                    startingIndex: sonosSource,
                    numberOfTracks: 1,
                    insertBefore: sonosDest
                )
            } catch {
                errorMessage = "Reorder failed: \(error.localizedDescription)"
                await refreshQueue()
            }
        }
    }

    // MARK: - Group Management

    func groupDevices(_ device: SonosDevice, with coordinator: SonosDevice) async {
        do {
            try await zoneService.joinGroup(device: device, coordinatorDevice: coordinator)
            try? await Task.sleep(for: .milliseconds(500))
            await refreshGroups()
        } catch {
            errorMessage = "Group failed: \(error.localizedDescription)"
        }
    }

    func ungroupDevice(_ device: SonosDevice) async {
        do {
            try await zoneService.leaveGroup(device: device)
            try? await Task.sleep(for: .milliseconds(500))
            await refreshGroups()
        } catch {
            errorMessage = "Ungroup failed: \(error.localizedDescription)"
        }
    }

    // MARK: - EQ

    func refreshEQ() async {
        guard let group = selectedGroup else { return }
        do {
            bass = try await rendering.getBass(device: group.coordinator)
            treble = try await rendering.getTreble(device: group.coordinator)
        } catch {
            // Silently ignore
        }
    }

    func setBass(_ level: Int) async {
        guard let group = selectedGroup else { return }
        bass = level
        do {
            try await rendering.setBass(device: group.coordinator, level: level)
        } catch {
            errorMessage = "Bass adjustment failed: \(error.localizedDescription)"
        }
    }

    func setTreble(_ level: Int) async {
        guard let group = selectedGroup else { return }
        treble = level
        do {
            try await rendering.setTreble(device: group.coordinator, level: level)
        } catch {
            errorMessage = "Treble adjustment failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int) async {
        guard let group = selectedGroup else { return }
        let h = minutes / 60
        let m = minutes % 60
        let duration = String(format: "%02d:%02d:%02d", h, m, 0)
        do {
            try await transport.configureSleepTimer(device: group.coordinator, duration: duration)
            sleepTimerRemaining = TimeInterval(minutes * 60)
            startSleepTimerCountdown()
        } catch {
            errorMessage = "Sleep timer failed: \(error.localizedDescription)"
        }
    }

    func cancelSleepTimer() async {
        guard let group = selectedGroup else { return }
        do {
            try await transport.configureSleepTimer(device: group.coordinator, duration: "")
            sleepTimerRemaining = nil
            sleepTimerCountdown?.invalidate()
            sleepTimerCountdown = nil
        } catch {
            errorMessage = "Cancel sleep timer failed: \(error.localizedDescription)"
        }
    }

    func refreshSleepTimer() async {
        guard let group = selectedGroup else { return }
        do {
            let durationStr = try await transport.getSleepTimerDuration(device: group.coordinator)
            if durationStr.isEmpty || durationStr == "0" || durationStr == "" {
                sleepTimerRemaining = nil
                sleepTimerCountdown?.invalidate()
                sleepTimerCountdown = nil
            } else {
                let remaining = XMLHelper.parseDuration(durationStr)
                if remaining > 0 {
                    sleepTimerRemaining = remaining
                    startSleepTimerCountdown()
                } else {
                    sleepTimerRemaining = nil
                    sleepTimerCountdown?.invalidate()
                    sleepTimerCountdown = nil
                }
            }
        } catch {
            // Silently ignore
        }
    }

    private var sleepTimerEndDate: Date?

    private func startSleepTimerCountdown() {
        sleepTimerCountdown?.invalidate()
        // Use absolute end time to avoid timer drift from imprecise intervals or app sleep
        if let remaining = sleepTimerRemaining {
            sleepTimerEndDate = Date().addingTimeInterval(remaining)
        }
        sleepTimerCountdown = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let endDate = self.sleepTimerEndDate else { return }
                let remaining = endDate.timeIntervalSinceNow
                if remaining > 0 {
                    self.sleepTimerRemaining = remaining
                } else {
                    self.sleepTimerRemaining = nil
                    self.sleepTimerEndDate = nil
                    self.sleepTimerCountdown?.invalidate()
                    self.sleepTimerCountdown = nil
                }
            }
        }
    }

    // MARK: - Crossfade

    func refreshCrossfade() async {
        guard let group = selectedGroup else { return }
        do {
            isCrossfadeEnabled = try await transport.getCrossfadeMode(device: group.coordinator)
        } catch {
            // Silently ignore
        }
    }

    func toggleCrossfade() async {
        guard let group = selectedGroup else { return }
        let newValue = !isCrossfadeEnabled
        isCrossfadeEnabled = newValue
        do {
            try await transport.setCrossfadeMode(device: group.coordinator, enabled: newValue)
        } catch {
            errorMessage = "Crossfade toggle failed: \(error.localizedDescription)"
            isCrossfadeEnabled = !newValue
        }
    }

    // MARK: - Music Library

    func browseLibrary(section: LibrarySection? = nil) {
        let objectID: String
        let title: String
        if let section = section {
            objectID = section.rawValue
            title = section.displayName
        } else {
            // Reset to root
            libraryPath = []
            libraryItems = []
            libraryTotalMatches = 0
            return
        }

        libraryPath = [LibraryBreadcrumb(objectID: objectID, title: title)]
        libraryItems = []
        libraryTotalMatches = 0

        Task { await loadLibraryItems(objectID: objectID) }
    }

    func browseContainer(_ item: BrowsableItem) {
        libraryPath.append(LibraryBreadcrumb(objectID: item.id, title: item.title))
        libraryItems = []
        libraryTotalMatches = 0

        Task { await loadLibraryItems(objectID: item.id) }
    }

    func navigateLibraryTo(_ breadcrumb: LibraryBreadcrumb) {
        guard let index = libraryPath.firstIndex(where: { $0.id == breadcrumb.id }) else { return }
        libraryPath = Array(libraryPath.prefix(through: index))
        libraryItems = []
        libraryTotalMatches = 0

        Task { await loadLibraryItems(objectID: breadcrumb.objectID) }
    }

    func navigateLibraryBack() {
        guard libraryPath.count > 1 else {
            // Go back to section grid
            libraryPath = []
            libraryItems = []
            libraryTotalMatches = 0
            return
        }
        libraryPath.removeLast()
        libraryItems = []
        libraryTotalMatches = 0

        if let last = libraryPath.last {
            Task { await loadLibraryItems(objectID: last.objectID) }
        }
    }

    func loadMoreLibraryItems() {
        guard !isLoadingLibrary, libraryItems.count < libraryTotalMatches,
              let last = libraryPath.last else { return }
        Task { await loadLibraryItems(objectID: last.objectID, start: libraryItems.count) }
    }

    private func loadLibraryItems(objectID: String, start: Int = 0) async {
        guard let group = selectedGroup else { return }
        isLoadingLibrary = true
        do {
            let result = try await libraryService.browse(
                device: group.coordinator, objectID: objectID, start: start, count: 100
            )
            if start == 0 {
                libraryItems = result.items
            } else {
                libraryItems.append(contentsOf: result.items)
            }
            libraryTotalMatches = result.totalMatches
        } catch {
            errorMessage = "Library browse failed: \(error.localizedDescription)"
        }
        isLoadingLibrary = false
    }

    func playAllLibraryItems() async {
        guard let group = selectedGroup, !libraryItems.isEmpty else { return }
        let playableItems = libraryItems.filter { !$0.isContainer && !$0.uri.isEmpty }
        guard !playableItems.isEmpty else { return }
        do {
            try await transport.removeAllTracksFromQueue(device: group.coordinator)
            for item in playableItems {
                try await transport.addURIToQueue(device: group.coordinator, uri: item.uri)
            }
            try await transport.seekTrack(device: group.coordinator, trackNumber: 1)
            try await transport.play(device: group.coordinator)
            await refreshQueue()
            await refreshTransport()
        } catch {
            errorMessage = "Play all failed: \(error.localizedDescription)"
        }
    }

    func addLibraryItemToQueue(_ item: BrowsableItem) async {
        guard let group = selectedGroup else { return }
        do {
            if item.isContainer {
                // Browse the container and add all tracks
                let result = try await libraryService.browse(
                    device: group.coordinator, objectID: item.id, start: 0, count: 500
                )
                for child in result.items where !child.isContainer && !child.uri.isEmpty {
                    try await transport.addURIToQueue(device: group.coordinator, uri: child.uri)
                }
            } else {
                try await transport.addURIToQueue(device: group.coordinator, uri: item.uri)
            }
            await refreshQueue()
        } catch {
            errorMessage = "Add to queue failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Favorites & Playlists

    func refreshFavorites() async {
        guard let group = selectedGroup else { return }
        do {
            let result = try await libraryService.browse(
                device: group.coordinator, objectID: "FV:2", start: 0, count: 100
            )
            favorites = result.items
        } catch {
            errorMessage = "Favorites fetch failed: \(error.localizedDescription)"
        }
    }

    func refreshPlaylists() async {
        guard let group = selectedGroup else { return }
        do {
            let result = try await libraryService.browse(
                device: group.coordinator, objectID: "SQ:", start: 0, count: 100
            )
            playlists = result.items
        } catch {
            errorMessage = "Playlists fetch failed: \(error.localizedDescription)"
        }
    }

    func playFavoriteOrPlaylist(_ item: BrowsableItem) async {
        guard let group = selectedGroup else { return }
        do {
            let uri = item.uri
            let metadata = ""
            try await transport.removeAllTracksFromQueue(device: group.coordinator)
            if item.isContainer || uri.isEmpty {
                // For playlists/containers, browse and add all tracks
                let result = try await libraryService.browse(
                    device: group.coordinator, objectID: item.id, start: 0, count: 500
                )
                for child in result.items where !child.uri.isEmpty {
                    try await transport.addURIToQueue(device: group.coordinator, uri: child.uri)
                }
                try await transport.seekTrack(device: group.coordinator, trackNumber: 1)
                try await transport.play(device: group.coordinator)
            } else {
                try await transport.setAVTransportURI(device: group.coordinator, uri: uri, metadata: metadata)
                try await transport.play(device: group.coordinator)
            }
            await refreshQueue()
            await refreshTransport()
        } catch {
            errorMessage = "Play failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Input Source Switching

    func switchToLineIn() async {
        guard let group = selectedGroup else { return }
        let device = group.coordinator
        guard device.hasLineIn else { return }
        do {
            try await transport.setAVTransportURI(device: device, uri: device.lineInURI)
            try await transport.play(device: device)
            currentInputSource = .lineIn
        } catch {
            errorMessage = "Switch to line-in failed: \(error.localizedDescription)"
        }
    }

    func switchToTVInput() async {
        guard let group = selectedGroup else { return }
        let device = group.coordinator
        guard device.hasTVInput else { return }
        do {
            try await transport.setAVTransportURI(device: device, uri: device.tvInputURI)
            try await transport.play(device: device)
            currentInputSource = .tvInput
        } catch {
            errorMessage = "Switch to TV input failed: \(error.localizedDescription)"
        }
    }

    func switchToQueue() async {
        guard let group = selectedGroup else { return }
        do {
            // Set transport back to queue
            let queueURI = "x-rincon-queue:\(group.coordinator.rinconID)#0"
            try await transport.setAVTransportURI(device: group.coordinator, uri: queueURI)
            currentInputSource = .queue
        } catch {
            errorMessage = "Switch to queue failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Apple Music

    func checkAppleMusicAuth() {
        appleMusicAuthorized = (MusicAuthorization.currentStatus == .authorized)
    }

    func requestAppleMusicAuth() {
        Task {
            let status = await appleMusicService.requestAuthorization()
            appleMusicAuthorized = (status == .authorized)
            if status == .denied {
                errorMessage = "Apple Music access was denied. Enable it in System Settings > Privacy & Security > Media & Apple Music."
            }
        }
    }

    func browseAppleMusic(category: AppleMusicCategory) {
        appleMusicPath = [AppleMusicBreadcrumb(title: category.rawValue, itemType: .category, musicKitID: category.rawValue)]
        appleMusicItems = []
        isLoadingAppleMusic = true

        Task {
            do {
                let items: [AppleMusicItem]
                switch category {
                case .topCharts:
                    items = try await appleMusicService.getTopCharts()
                case .newMusic:
                    // Use charts for new music as well
                    items = try await appleMusicService.getTopCharts()
                case .playlists:
                    items = try await appleMusicService.getTopCharts()
                case .genres, .recommendations:
                    items = try await appleMusicService.getTopCharts()
                }
                appleMusicItems = items
                appleMusicTotalMatches = items.count
            } catch {
                errorMessage = "Apple Music browse failed: \(error.localizedDescription)"
            }
            isLoadingAppleMusic = false
        }
    }

    func browseAppleMusicContainer(_ item: AppleMusicItem) {
        appleMusicPath.append(AppleMusicBreadcrumb(title: item.title, itemType: item.itemType, musicKitID: item.musicKitID))
        appleMusicItems = []
        isLoadingAppleMusic = true

        Task {
            do {
                let items: [AppleMusicItem]
                switch item.itemType {
                case .artist:
                    items = try await appleMusicService.getArtistAlbums(id: item.musicKitID)
                case .album:
                    items = try await appleMusicService.getAlbumTracks(id: item.musicKitID)
                case .playlist:
                    items = try await appleMusicService.getPlaylistTracks(id: item.musicKitID)
                default:
                    items = []
                }
                appleMusicItems = items
                appleMusicTotalMatches = items.count
            } catch {
                errorMessage = "Apple Music browse failed: \(error.localizedDescription)"
            }
            isLoadingAppleMusic = false
        }
    }

    func searchAppleMusic(query: String) {
        appleMusicSearchQuery = query
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            appleMusicItems = []
            appleMusicTotalMatches = 0
            return
        }

        appleMusicPath = []
        appleMusicItems = []
        isLoadingAppleMusic = true

        Task {
            do {
                let items = try await appleMusicService.search(term: query)
                appleMusicItems = items
                appleMusicTotalMatches = items.count
            } catch {
                errorMessage = "Apple Music search failed: \(error.localizedDescription)"
            }
            isLoadingAppleMusic = false
        }
    }

    func navigateAppleMusicBack() {
        guard appleMusicPath.count > 1 else {
            appleMusicPath = []
            appleMusicItems = []
            appleMusicTotalMatches = 0
            return
        }
        appleMusicPath.removeLast()
        if let last = appleMusicPath.last {
            // Reload the previous level
            let crumb = last
            appleMusicItems = []
            isLoadingAppleMusic = true
            Task {
                do {
                    let items: [AppleMusicItem]
                    switch crumb.itemType {
                    case .category:
                        items = try await appleMusicService.getTopCharts()
                    case .artist:
                        items = try await appleMusicService.getArtistAlbums(id: crumb.musicKitID)
                    case .album:
                        items = try await appleMusicService.getAlbumTracks(id: crumb.musicKitID)
                    case .playlist:
                        items = try await appleMusicService.getPlaylistTracks(id: crumb.musicKitID)
                    default:
                        items = []
                    }
                    appleMusicItems = items
                    appleMusicTotalMatches = items.count
                } catch {
                    errorMessage = "Apple Music browse failed: \(error.localizedDescription)"
                }
                isLoadingAppleMusic = false
            }
        }
    }

    func navigateAppleMusicTo(_ breadcrumb: AppleMusicBreadcrumb) {
        guard let index = appleMusicPath.firstIndex(where: { $0.id == breadcrumb.id }) else { return }
        appleMusicPath = Array(appleMusicPath.prefix(through: index))

        let crumb = breadcrumb
        appleMusicItems = []
        isLoadingAppleMusic = true
        Task {
            do {
                let items: [AppleMusicItem]
                switch crumb.itemType {
                case .category:
                    items = try await appleMusicService.getTopCharts()
                case .artist:
                    items = try await appleMusicService.getArtistAlbums(id: crumb.musicKitID)
                case .album:
                    items = try await appleMusicService.getAlbumTracks(id: crumb.musicKitID)
                case .playlist:
                    items = try await appleMusicService.getPlaylistTracks(id: crumb.musicKitID)
                default:
                    items = []
                }
                appleMusicItems = items
                appleMusicTotalMatches = items.count
            } catch {
                errorMessage = "Apple Music browse failed: \(error.localizedDescription)"
            }
            isLoadingAppleMusic = false
        }
    }

    func playAppleMusicItem(_ item: AppleMusicItem) {
        Task {
            do {
                try await appleMusicService.play(item: item)
                isAppleMusicPlaying = true
            } catch {
                errorMessage = "Apple Music play failed: \(error.localizedDescription)"
            }
        }
    }

    func addAppleMusicToQueue(_ item: AppleMusicItem) {
        // For Apple Music, playing an item sets it as the current queue in ApplicationMusicPlayer
        playAppleMusicItem(item)
    }
}
